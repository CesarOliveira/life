# Gera o XML (plist) de um atalho do iPhone (.shortcut). O iOS só importa
# atalhos ASSINADOS, então o fluxo é: gerar XML -> assinar num Mac -> hospedar.
#
# Regenerar e reassinar o arquivo servido (rodar no Mac, na raiz do repo):
#   ruby -e 'require "./app/services/health_shortcut_builder"; \
#     print HealthShortcutBuilder.new(token: "TOKEN_PLACEHOLDER", \
#     endpoint: "https://life.cesaroliveira.online/api/metrics").plist' > /tmp/sc.shortcut
#   shortcuts sign --mode anyone --input /tmp/sc.shortcut \
#     --output public/shortcuts/saude-life.shortcut
#
# v1 (validação do pipeline): [Texto: JSON fixo] -> [Obter conteúdo de URL: POST].
# Próximas versões inserem as ações de Saúde (passos/sono) antes do Texto.
class HealthShortcutBuilder
  # UUIDs fixos para ligar a saída do Texto ao corpo da requisição.
  TEXT_UUID = "A1B2C3D4-0001-4000-8000-000000000001".freeze

  def initialize(token:, endpoint:)
    @token = token
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
        <array/>
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
          #{text_action}
          #{post_action}
        </array>
      </dict>
      </plist>
    XML
  end

  private

  def text_action
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.gettext</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>UUID</key>
          <string>#{TEXT_UUID}</string>
          <key>WFTextActionText</key>
          <string>#{xml_escape(body_json)}</string>
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
          #{text_variable_reference}
        </dict>
      </dict>
    XML
  end

  def headers_field
    <<~XML
      <dict>
        <key>Value</key>
        <dict>
          <key>WFDictionaryFieldValueItems</key>
          <array>
            #{header_item("Authorization", "Bearer #{@token}")}
            #{header_item("Content-Type", "application/json")}
          </array>
        </dict>
        <key>WFSerializationType</key>
        <string>WFDictionaryFieldValue</string>
      </dict>
    XML
  end

  def header_item(key, value)
    <<~XML
      <dict>
        <key>WFItemType</key>
        <integer>0</integer>
        <key>WFKey</key>
        #{plain_text_token(key)}
        <key>WFValue</key>
        #{plain_text_token(value)}
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

  def text_variable_reference
    <<~XML
      <dict>
        <key>Value</key>
        <dict>
          <key>OutputName</key>
          <string>Texto</string>
          <key>OutputUUID</key>
          <string>#{TEXT_UUID}</string>
          <key>Type</key>
          <string>ActionOutput</string>
        </dict>
        <key>WFSerializationType</key>
        <string>WFTextTokenAttachment</string>
      </dict>
    XML
  end

  def body_json
    %({"period":"yesterday","metrics":[{"key":"steps","value":1234}]})
  end

  def xml_escape(str)
    str.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
  end
end
