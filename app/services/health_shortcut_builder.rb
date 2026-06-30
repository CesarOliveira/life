# Gera o XML (plist) do atalho do iPhone (.shortcut). O iOS só importa atalhos
# ASSINADOS, então o fluxo é: gerar XML -> assinar num Mac (`shortcuts sign`) ->
# hospedar o arquivo assinado em public/shortcuts/.
#
# Regenerar e reassinar (rodar no Mac, na raiz do repo):
#   ruby -e 'require "./app/services/health_shortcut_builder"; \
#     print HealthShortcutBuilder.new(endpoint: "https://life.cesaroliveira.online/api/health_raw").plist' \
#     > /tmp/sc.shortcut
#   shortcuts sign --mode anyone --input /tmp/sc.shortcut --output public/shortcuts/saude-life.shortcut
#
# v6 — "cano burro" + driblando o bloqueio de privacidade do iOS.
# O iOS não deixa enviar OBJETOS de Saúde para uma URL ("tentando compartilhar
# N itens do app Saúde"). Então, em vez de mandar as amostras cruas, o atalho
# percorre cada amostra e EXTRAI só o número (Obter Detalhes -> Valor) — isso é
# leitura, não cálculo — junta os números (um por linha) e envia texto puro.
# O Rails (POST /api/health_raw) é quem SOMA.
#   Ações: [Localizar passos] -> [Repetir: Obter Valor -> Adicionar à variável]
#          -> [Combinar texto] -> [Texto token] -> [POST]
# O caractere U+FFFC (￼) marca onde uma variável é inserida no texto.
class HealthShortcutBuilder
  # Marcador de versão: vai na query ("client_version") e o servidor devolve na
  # resposta. Bumpe a cada build para confirmar que NÃO baixou arquivo cacheado.
  VERSION = "v6".freeze

  TOKEN_UUID = "11111111-1111-1111-1111-111111111111".freeze
  STEPS_FIND_UUID = "22222222-2222-2222-2222-222222222222".freeze
  COMBINE_UUID = "33333333-3333-3333-3333-333333333333".freeze
  REPEAT_GROUP_UUID = "44444444-4444-4444-4444-444444444444".freeze
  DETAIL_UUID = "55555555-5555-5555-5555-555555555555".freeze
  SAMPLES_VAR = "Samples".freeze
  OBJ = "\u{FFFC}".freeze # placeholder de anexo (object replacement char)

  # Índice (0-based) da ação Texto do token na lista de ações — usado pela
  # pergunta de importação que preenche o token.
  TOKEN_ACTION_INDEX = 6

  def initialize(endpoint:)
    @endpoint = endpoint
  end

  def filename
    "Saude-Life.shortcut"
  end

  # URL com metadados na query (a versão fica embutida no arquivo assinado).
  def post_url
    "#{@endpoint}?key=steps&period=today&client_version=#{VERSION}"
  end

  def plist
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>WFWorkflowClientVersion</key>
        <string>900</string>
        <key>WFWorkflowMinimumClientVersion</key>
        <integer>900</integer>
        <key>WFWorkflowMinimumClientVersionString</key>
        <string>900</string>
        <key>WFWorkflowIcon</key>
        <dict>
          <key>WFWorkflowIconStartColor</key>
          <integer>463140863</integer>
          <key>WFWorkflowIconGlyphNumber</key>
          <integer>61440</integer>
        </dict>
        <key>WFWorkflowImportQuestions</key>
        #{import_questions}
        <key>WFWorkflowTypes</key>
        <array/>
        <key>WFWorkflowInputContentItemClasses</key>
        <array>
          <string>WFStringContentItem</string>
          <string>WFURLContentItem</string>
          <string>WFDictionaryContentItem</string>
          <string>WFNumberContentItem</string>
        </array>
        <key>WFWorkflowActions</key>
        <array>
          #{steps_find_action}
          #{repeat_start_action}
          #{detail_value_action}
          #{append_variable_action}
          #{repeat_end_action}
          #{combine_text_action}
          #{token_action}
          #{post_action}
        </array>
      </dict>
      </plist>
    XML
  end

  private

  # Pergunta o token na hora de instalar e preenche a ação Texto do token.
  def import_questions
    <<~XML
      <array>
        <dict>
          <key>ParameterKey</key>
          <string>WFTextActionText</string>
          <key>Category</key>
          <string>Parameter</string>
          <key>ActionIndex</key>
          <integer>#{TOKEN_ACTION_INDEX}</integer>
          <key>Text</key>
          <string>Cole seu token do Life (página Tempo de tela)</string>
          <key>DefaultValue</key>
          <string></string>
        </dict>
      </array>
    XML
  end

  # 1) Localizar Amostras de Saúde: Passos, Data de Início nos últimos 1 dia.
  def steps_find_action
    health_find_action(STEPS_FIND_UUID, type_label: "Steps")
  end

  # 2) Repetir com Cada (início) sobre as amostras de passos.
  def repeat_start_action
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.repeat.each</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>WFControlFlowMode</key>
          <integer>0</integer>
          <key>GroupingIdentifier</key>
          <string>#{REPEAT_GROUP_UUID}</string>
          <key>WFInput</key>
          #{output_variable(STEPS_FIND_UUID, "Health Samples")}
        </dict>
      </dict>
    XML
  end

  # 3) Obter Detalhes da Amostra de Saúde -> "Valor" (número puro). Sem WFInput:
  #    usa o item atual do laço (Repeat Item). Ler o valor NÃO é cálculo.
  def detail_value_action
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.properties.health.quantity</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>UUID</key>
          <string>#{DETAIL_UUID}</string>
          <key>WFContentItemPropertyName</key>
          <string>Value</string>
        </dict>
      </dict>
    XML
  end

  # 4) Adicionar à Variável "Samples" (acumula a lista; não é cálculo).
  def append_variable_action
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.appendvariable</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>WFVariableName</key>
          <string>#{SAMPLES_VAR}</string>
          <key>WFInput</key>
          #{output_variable(DETAIL_UUID, "Health Sample Value")}
        </dict>
      </dict>
    XML
  end

  # 5) Repetir com Cada (fim).
  def repeat_end_action
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.repeat.each</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>WFControlFlowMode</key>
          <integer>2</integer>
          <key>GroupingIdentifier</key>
          <string>#{REPEAT_GROUP_UUID}</string>
        </dict>
      </dict>
    XML
  end

  # 6) Combinar Texto: junta os números por quebra de linha -> texto puro.
  def combine_text_action
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.text.combine</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>UUID</key>
          <string>#{COMBINE_UUID}</string>
          <key>WFTextSeparator</key>
          <string>New Lines</string>
          <key>WFInput</key>
          #{named_variable(SAMPLES_VAR)}
        </dict>
      </dict>
    XML
  end

  # 7) Texto do token (preenchido na importação).
  def token_action
    text_action(TOKEN_UUID, "")
  end

  # 8) POST com o texto combinado no corpo (File).
  def post_action
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.downloadurl</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>WFURL</key>
          <string>#{xml_escape(post_url)}</string>
          <key>WFHTTPMethod</key>
          <string>POST</string>
          <key>WFHTTPHeaders</key>
          #{headers_field}
          <key>WFHTTPBodyType</key>
          <string>File</string>
          <key>WFRequestVariable</key>
          #{output_variable(COMBINE_UUID, "Combined Text")}
        </dict>
      </dict>
    XML
  end

  # --- helpers de ações ---

  def text_action(uuid, text)
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.gettext</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>UUID</key>
          <string>#{uuid}</string>
          <key>WFTextActionText</key>
          <string>#{xml_escape(text)}</string>
        </dict>
      </dict>
    XML
  end

  def health_find_action(uuid, type_label:)
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.filter.health.quantity</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>UUID</key>
          <string>#{uuid}</string>
          <key>WFContentItemFilter</key>
          <dict>
            <key>Value</key>
            <dict>
              <key>WFActionParameterFilterPrefix</key>
              <integer>1</integer>
              <key>WFContentPredicateBoundedDate</key>
              <false/>
              <key>WFActionParameterFilterTemplates</key>
              <array>
                <dict>
                  <key>Bounded</key>
                  <true/>
                  <key>Operator</key>
                  <integer>4</integer>
                  <key>Property</key>
                  <string>Type</string>
                  <key>Removable</key>
                  <false/>
                  <key>Values</key>
                  <dict>
                    <key>Enumeration</key>
                    <dict>
                      <key>Value</key>
                      <string>#{xml_escape(type_label)}</string>
                      <key>WFSerializationType</key>
                      <string>WFStringSubstitutableState</string>
                    </dict>
                  </dict>
                </dict>
                <dict>
                  <key>Bounded</key>
                  <true/>
                  <key>Operator</key>
                  <integer>1001</integer>
                  <key>Property</key>
                  <string>Start Date</string>
                  <key>Removable</key>
                  <false/>
                  <key>Values</key>
                  <dict>
                    <key>Number</key>
                    <string>1</string>
                    <key>Unit</key>
                    <integer>16</integer>
                  </dict>
                </dict>
              </array>
            </dict>
            <key>WFSerializationType</key>
            <string>WFContentPredicateTableTemplate</string>
          </dict>
        </dict>
      </dict>
    XML
  end

  # --- helpers de tokens/variáveis ---

  # Referência a toda a saída de uma ação (variável inteira).
  def output_variable(uuid, name)
    <<~XML
      <dict>
        <key>WFSerializationType</key>
        <string>WFTextTokenAttachment</string>
        <key>Value</key>
        <dict>
          <key>OutputName</key>
          <string>#{xml_escape(name)}</string>
          <key>OutputUUID</key>
          <string>#{uuid}</string>
          <key>Type</key>
          <string>ActionOutput</string>
        </dict>
      </dict>
    XML
  end

  # Referência a uma variável NOMEADA (criada por "Adicionar à Variável").
  def named_variable(name)
    <<~XML
      <dict>
        <key>WFSerializationType</key>
        <string>WFTextTokenAttachment</string>
        <key>Value</key>
        <dict>
          <key>Type</key>
          <string>Variable</string>
          <key>VariableName</key>
          <string>#{xml_escape(name)}</string>
        </dict>
      </dict>
    XML
  end

  # Texto com UMA variável embutida no caractere U+FFFC (offset em UTF-16).
  def attachment_token(text, uuid, name)
    offset = text.index(OBJ)
    <<~XML
      <dict>
        <key>WFSerializationType</key>
        <string>WFTextTokenString</string>
        <key>Value</key>
        <dict>
          <key>string</key>
          <string>#{xml_escape(text)}</string>
          <key>attachmentsByRange</key>
          <dict>
            <key>{#{offset}, 1}</key>
            <dict>
              <key>OutputName</key>
              <string>#{xml_escape(name)}</string>
              <key>OutputUUID</key>
              <string>#{uuid}</string>
              <key>Type</key>
              <string>ActionOutput</string>
            </dict>
          </dict>
        </dict>
      </dict>
    XML
  end

  def plain_text_token(text)
    <<~XML
      <dict>
        <key>WFSerializationType</key>
        <string>WFTextTokenString</string>
        <key>Value</key>
        <dict>
          <key>string</key>
          <string>#{xml_escape(text)}</string>
        </dict>
      </dict>
    XML
  end

  def headers_field
    <<~XML
      <dict>
        <key>WFSerializationType</key>
        <string>WFDictionaryFieldValue</string>
        <key>Value</key>
        <dict>
          <key>WFDictionaryFieldValueItems</key>
          <array>
            #{header_item(plain_text_token("Authorization"), attachment_token("Bearer #{OBJ}", TOKEN_UUID, "Token"))}
            #{header_item(plain_text_token("Content-Type"), plain_text_token("text/plain"))}
          </array>
        </dict>
      </dict>
    XML
  end

  def header_item(key_token, value_token)
    <<~XML
      <dict>
        <key>WFItemType</key>
        <integer>0</integer>
        <key>WFKey</key>
        #{key_token}
        <key>WFValue</key>
        #{value_token}
      </dict>
    XML
  end

  def xml_escape(str)
    str.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
  end
end
