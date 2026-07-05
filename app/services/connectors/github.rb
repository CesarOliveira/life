require "net/http"
require "json"

module Connectors
  # Cliente GitHub: fluxo OAuth (App clássico -> token sem expiração, escopo
  # read:user) e GraphQL de contribuições (o "gráfico verde", dia a dia).
  class Github
    AUTHORIZE_URL = "https://github.com/login/oauth/authorize".freeze
    TOKEN_URL = "https://github.com/login/oauth/access_token".freeze
    API_URL = "https://api.github.com/graphql".freeze
    SCOPE = "read:user".freeze

    def self.configured?
      ENV["GITHUB_CLIENT_ID"].to_s.strip.present? && ENV["GITHUB_CLIENT_SECRET"].to_s.strip.present?
    end

    def self.authorize_url(state:, redirect_uri:)
      params = { client_id: ENV["GITHUB_CLIENT_ID"], redirect_uri: redirect_uri, scope: SCOPE, state: state }
      "#{AUTHORIZE_URL}?#{URI.encode_www_form(params)}"
    end

    # Troca o code por access_token. Levanta em erro (mensagem do GitHub).
    def self.exchange_code(code, redirect_uri:)
      uri = URI(TOKEN_URL)
      request = Net::HTTP::Post.new(uri)
      request["Accept"] = "application/json"
      request.set_form_data(client_id: ENV["GITHUB_CLIENT_ID"], client_secret: ENV["GITHUB_CLIENT_SECRET"],
                            code: code, redirect_uri: redirect_uri)
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
      body = JSON.parse(response.body)
      raise body["error_description"] || body["error"] if body["access_token"].blank?

      body["access_token"]
    end

    # Usuário dono do token.
    def self.viewer_login(token)
      graphql(token, "query { viewer { login } }").dig("data", "viewer", "login")
    end

    # Contribuições por dia no intervalo (máx. 1 ano por chamada na API).
    # Retorna [{ date: Date, count: Integer }].
    def self.contribution_days(token, from:, to:)
      query = <<~GRAPHQL
        query($from: DateTime!, $to: DateTime!) {
          viewer {
            contributionsCollection(from: $from, to: $to) {
              contributionCalendar { weeks { contributionDays { date contributionCount } } }
            }
          }
        }
      GRAPHQL
      data = graphql(token, query, from: "#{from.iso8601}T00:00:00Z", to: "#{to.iso8601}T23:59:59Z")
      weeks = data.dig("data", "viewer", "contributionsCollection", "contributionCalendar", "weeks") || []
      weeks.flat_map { |w| w["contributionDays"] }
           .map { |d| { date: Date.iso8601(d["date"]), count: d["contributionCount"].to_i } }
    end

    def self.graphql(token, query, variables = {})
      uri = URI(API_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Content-Type"] = "application/json"
      request.body = { query: query, variables: variables }.to_json
      response = http.request(request)
      raise "GitHub HTTP #{response.code}" unless response.code.to_i == 200

      parsed = JSON.parse(response.body)
      raise parsed["errors"].map { |e| e["message"] }.join("; ") if parsed["errors"].present?

      parsed
    end
  end
end
