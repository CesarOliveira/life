module Mcp
  # Servidor MCP (Model Context Protocol) mínimo, sem estado, sobre JSON-RPC 2.0.
  # Expõe FERRAMENTAS (ver Mcp::Tools) para um assistente de IA cruzar tempo de
  # tela, saúde, treinos, tarefas, hábitos e exames da conta. As de escrita só
  # existem quando o usuário deu a permissão life:write.
  class Server
    PROTOCOL_VERSIONS = %w[2025-06-18 2025-03-26 2024-11-05].freeze
    VERSION = "1.0.0".freeze

    INSTRUCTIONS = <<~TEXT.squish.freeze
      Life é o diário pessoal de dados do usuário: tempo de tela do iPhone por app, saúde do iPhone e Apple Watch
      (sono, atividade, coração, treinos), tarefas em quadros kanban, hábitos, peso e exames de laboratório.
      Todas as ferramentas são somente leitura. Datas são dias locais (America/Sao_Paulo) no formato AAAA-MM-DD e
      durações vêm em minutos. Comece por get_overview para ver o que existe e o período coberto; depois use as
      ferramentas específicas. Ao cruzar dados, lembre que o dia mais recente pode estar incompleto e que
      correlação não é causa. Não é aconselhamento médico: para exames e sintomas, oriente procurar um profissional.
    TEXT

    WRITE_INSTRUCTIONS = <<~TEXT.squish.freeze
      O usuário também autorizou alterações: você pode criar, editar, mover e comentar tarefas, marcar hábitos manuais
      e registrar peso. Só altere quando o usuário pedir ou concordar; diga o que fez depois. Não existe ferramenta de exclusão.
    TEXT

    def initialize(account, write: false, user: nil)
      @account = account
      @write = write
      @tools = Tools.new(account, write: write, user: user)
    end

    # Recebe uma mensagem JSON-RPC (Hash) e devolve a resposta (Hash) ou nil
    # quando é notificação (sem id).
    def handle(message)
      return error(nil, -32_600, "Invalid Request") unless message.is_a?(Hash) && message["jsonrpc"] == "2.0"

      id = message["id"]
      method = message["method"].to_s
      return nil if id.nil? # notificações (ex.: notifications/initialized) não têm resposta

      case method
      when "initialize" then result(id, initialize_result(message["params"]))
      when "ping" then result(id, {})
      when "tools/list" then result(id, { tools: @tools.definitions })
      when "tools/call" then call_tool(id, message["params"])
      else error(id, -32_601, "Method not found: #{method}")
      end
    end

    private

    def initialize_result(params)
      requested = params.is_a?(Hash) ? params["protocolVersion"].to_s : ""
      {
        protocolVersion: PROTOCOL_VERSIONS.include?(requested) ? requested : PROTOCOL_VERSIONS.first,
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: "life", title: "Life", version: VERSION },
        instructions: @write ? "#{INSTRUCTIONS.sub('Todas as ferramentas são somente leitura. ', '')} #{WRITE_INSTRUCTIONS}" : INSTRUCTIONS
      }
    end

    def call_tool(id, params)
      name = params.is_a?(Hash) ? params["name"].to_s : ""
      return error(id, -32_602, "Unknown tool: #{name}") unless @tools.known?(name)

      arguments = params["arguments"].is_a?(Hash) ? params["arguments"] : {}
      data = @tools.call(name, arguments)
      result(id, { content: [{ type: "text", text: JSON.generate(data) }], isError: false })
    rescue Tools::InvalidArguments => e
      # Erro de uso da ferramenta: volta como resultado, para o modelo corrigir e tentar de novo.
      result(id, { content: [{ type: "text", text: e.message }], isError: true })
    end

    def result(id, payload)
      { jsonrpc: "2.0", id: id, result: payload }
    end

    def error(id, code, message)
      { jsonrpc: "2.0", id: id, error: { code: code, message: message } }
    end
  end
end
