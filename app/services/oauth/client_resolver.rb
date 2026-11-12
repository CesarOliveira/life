require "net/http"
require "resolv"
require "ipaddr"

module Oauth
  # Acha o cliente OAuth pelo client_id. Dois tipos:
  # - cadastro automático (DCR): id aleatório, já está no banco;
  # - identidade publicada (CIMD): o client_id É uma URL https com um JSON
  #   (client_id, client_name, redirect_uris). O documento é buscado e guardado.
  #
  # Buscar uma URL informada por terceiros é porta para SSRF, então: só https,
  # sem redirecionamento, sem endereços internos, com limite de tempo e tamanho.
  class ClientResolver
    MAX_BYTES = 64_000
    TIMEOUT = 5
    REFRESH_AFTER = 24.hours

    def self.call(client_id)
      new(client_id).call
    end

    def initialize(client_id)
      @client_id = client_id.to_s.strip
    end

    def call
      return nil if @client_id.blank? || @client_id.length > 500

      client = OauthClient.find_by(client_id: @client_id)
      return client unless url_client?
      return client if client && client.metadata_fetched_at && client.metadata_fetched_at > REFRESH_AFTER.ago

      refresh(client) || client
    end

    private

    def url_client?
      @client_id.start_with?("https://")
    end

    def refresh(client)
      document = fetch_document
      return nil if document.nil? || document["client_id"] != @client_id

      uris = Array(document["redirect_uris"]).map(&:to_s).first(20)
      client ||= OauthClient.new(client_id: @client_id, kind: "cimd")
      client.assign_attributes(name: document["client_name"].to_s.first(120).presence, redirect_uris: uris, metadata_fetched_at: Time.current)
      client.save ? client : nil
    rescue ActiveRecord::RecordNotUnique
      OauthClient.find_by(client_id: @client_id)
    end

    def fetch_document
      uri = URI.parse(@client_id)
      return nil unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.path.present? && uri.path != "/" && uri.userinfo.nil?

      addresses = public_addresses(uri.host)
      return nil if addresses.empty?

      # Tenta cada IP validado (IPv4 primeiro: há redes de hospedagem sem rota IPv6).
      addresses.each do |address|
        document = request_document(uri, address)
        return document if document
      end
      nil
    rescue URI::InvalidURIError
      nil
    end

    def request_document(uri, address)
      http = Net::HTTP.new(uri.host, uri.port)
      http.ipaddr = address # conecta no IP já validado (evita troca de DNS entre checar e conectar)
      http.use_ssl = true
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT
      response = http.request_get(uri.request_uri, "Accept" => "application/json", "User-Agent" => "Life-MCP/1.0")
      return nil unless response.is_a?(Net::HTTPOK) && response.body.to_s.bytesize <= MAX_BYTES

      parsed = JSON.parse(response.body)
      parsed.is_a?(Hash) ? parsed : nil
    rescue StandardError => e
      Rails.logger.warn("OAuth CIMD: falha ao ler #{@client_id} via #{address}: #{e.class}")
      nil
    end

    # IPs públicos do host, IPv4 primeiro. Vazio se QUALQUER endereço for interno
    # (um host que resolve para dentro da rede não é confiável, nem em parte).
    def public_addresses(host)
      addresses = Resolv.getaddresses(host)
      return [] if addresses.empty? || addresses.any? { |address| internal?(IPAddr.new(address)) }

      addresses.sort_by { |address| IPAddr.new(address).ipv4? ? 0 : 1 }.first(4)
    rescue IPAddr::InvalidAddressError, Resolv::ResolvError
      []
    end

    def internal?(ip)
      ip.loopback? || ip.private? || ip.link_local? || ip.to_s == "0.0.0.0" || ip.to_s == "::" ||
        (ip.ipv4? && IPAddr.new("100.64.0.0/10").include?(ip)) || (ip.ipv6? && ip.ipv4_mapped?)
    end
  end
end
