# Gera o XML (plist) do atalho do iPhone (.shortcut). O iOS só importa atalhos
# ASSINADOS, então o fluxo é: gerar XML -> assinar num Mac (`shortcuts sign`) ->
# hospedar o arquivo assinado em public/shortcuts/.
#
# Regenerar e reassinar (rodar no Mac, na raiz do repo):
#   ruby -e 'require "./app/services/health_shortcut_builder"; \
#     print HealthShortcutBuilder.new(endpoint: "https://life.cesaroliveira.online/api/metrics").plist' \
#     > /tmp/sc.shortcut
#   shortcuts sign --mode anyone --input /tmp/sc.shortcut --output public/shortcuts/saude-life.shortcut
#
# v3: token perguntado no import (sem edição manual) + passos reais.
#   Ordem importa: a "Somar" vem LOGO DEPOIS da busca de passos, e o Texto do
#   token vem DEPOIS — assim o encaixe automático do iOS (caso o link explícito
#   falhe) pega a ação anterior correta, não o token.
#   Ações: [Localizar passos] -> [Somar] -> [Texto JSON c/ soma] -> [Texto token] -> [POST]
# O caractere U+FFFC (￼) marca onde uma variável é inserida no texto.
class HealthShortcutBuilder
  TOKEN_UUID = "11111111-1111-1111-1111-111111111111".freeze
  STEPS_FIND_UUID = "22222222-2222-2222-2222-222222222222".freeze
  STEPS_SUM_UUID = "33333333-3333-3333-3333-333333333333".freeze
  BODY_UUID = "44444444-4444-4444-4444-444444444444".freeze
  OBJ = "\u{FFFC}".freeze # placeholder de anexo (object replacement char)

  def initialize(endpoint:)
    @endpoint = endpoint
  end

  def filename
    "Saude-Life.shortcut"
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
          #{steps_sum_action}
          #{body_action}
          #{token_action}
          #{post_action}
        </array>
      </dict>
      </plist>
    XML
  end

  private

  # Pergunta o token na hora de instalar e preenche a ação Texto do token (índice 3).
  def import_questions
    <<~XML
      <array>
        <dict>
          <key>ParameterKey</key>
          <string>WFTextActionText</string>
          <key>Category</key>
          <string>Parameter</string>
          <key>ActionIndex</key>
          <integer>3</integer>
          <key>Text</key>
          <string>Cole seu token do Life (página Tempo de tela)</string>
          <key>DefaultValue</key>
          <string></string>
        </dict>
      </array>
    XML
  end

  def token_action
    text_action(TOKEN_UUID, "")
  end

  # Localizar Amostras de Saúde: Passos, Data de Início nos últimos 1 dia.
  def steps_find_action
    health_find_action(STEPS_FIND_UUID, type_label: "Steps")
  end

  # Calcular Estatísticas: Soma sobre as amostras de passos.
  def steps_sum_action
    statistics_action(STEPS_SUM_UUID, input_uuid: STEPS_FIND_UUID, operation: "Sum", input_name: "Health Samples")
  end

  # Texto com o JSON do corpo, inserindo a soma de passos (como string).
  def body_action
    json = %({"period":"yesterday","metrics":[{"key":"steps","value":"#{OBJ}"}]})
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.gettext</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>UUID</key>
          <string>#{BODY_UUID}</string>
          <key>WFTextActionText</key>
          #{attachment_token(json, STEPS_SUM_UUID, "Statistics Result")}
        </dict>
      </dict>
    XML
  end

  def post_action
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.downloadurl</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>WFURL</key>
          <string>#{xml_escape(@endpoint)}</string>
          <key>WFHTTPMethod</key>
          <string>POST</string>
          <key>WFHTTPHeaders</key>
          #{headers_field}
          <key>WFHTTPBodyType</key>
          <string>File</string>
          <key>WFRequestVariable</key>
          #{output_variable(BODY_UUID, "Text")}
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

  def statistics_action(uuid, input_uuid:, operation:, input_name:)
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.statistics</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>UUID</key>
          <string>#{uuid}</string>
          <key>WFStatisticsOperation</key>
          <string>#{operation}</string>
          <key>WFInput</key>
          #{output_variable(input_uuid, input_name)}
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
            #{header_item(plain_text_token("Content-Type"), plain_text_token("application/json"))}
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
