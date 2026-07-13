# Gera o XML (plist) do atalho do iPhone (.shortcut) de TEMPO DE TELA. A Saúde
# (passos/FC/sono) migrou para o app nativo (life_app); este atalho existe só
# porque a Apple NÃO deixa app nativo ler o tempo de uso por app — só o Atalho
# consegue exportar isso.
#
# O iOS só importa atalhos ASSINADOS: gerar XML -> assinar num Mac
# (`shortcuts sign`) -> hospedar o assinado em public/shortcuts/.
#
# Regenerar e reassinar (rodar no Mac, na raiz do repo):
#   ruby -e 'require "./app/services/health_shortcut_builder"; \
#     print HealthShortcutBuilder.new(endpoint: "https://life.cesaroliveira.online/api/usage_raw").plist' \
#     > /tmp/sc.shortcut
#   shortcuts sign --mode anyone --input /tmp/sc.shortcut --output public/shortcuts/saude-life.shortcut
#
# Fluxo: [Texto do token] -> [Obter Atividade em Apps (during=yesterday)] ->
# [Repetir: Texto do item] -> [Combinar] -> [POST /api/usage_raw]. O servidor
# parseia "Nome (2h 36min)" e agrega.
class HealthShortcutBuilder
  # Marcador de versão: vai na query ("client_version"); o servidor devolve na
  # resposta. Bumpe a cada build p/ confirmar que NÃO baixou arquivo cacheado.
  VERSION = "v13".freeze

  # Nome fixo do atalho na biblioteca (WFWorkflowName no plist). Deixa o URL
  # scheme "shortcuts://run-shortcut?name=..." achar o atalho de forma confiável
  # (o botão "atualizar agora"). Renomear o atalho no iPhone quebra o botão.
  SHORTCUT_NAME = "Life Tempo de Tela".freeze

  TOKEN_UUID = "11111111-1111-1111-1111-111111111111".freeze
  REPEAT_ITEM_VAR = "Repeat Item".freeze # nome interno (inglês) do item do laço
  OBJ = "\u{FFFC}".freeze # placeholder de anexo (object replacement char)
  TOKEN_ACTION_INDEX = 0 # a ação Texto do token é a primeira

  # Bloco de Tempo de tela (App Intents, iOS 26).
  ACTIVITY_ACTION_ID = "com.apple.intelligenceplatform.IntelligencePlatform.IntelligencePlatformDataActionsAppIntentsExtension.CalculateAppUsageIntent".freeze
  ACT_UUID = "77777777-7777-7777-7777-777777777777".freeze
  ST_GROUP_UUID = "88888888-8888-8888-8888-888888888888".freeze
  STX_UUID = "99999999-9999-9999-9999-999999999999".freeze
  ST_END_UUID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa".freeze
  SCOMB_UUID = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb".freeze

  def initialize(endpoint:, token: nil)
    # Aceita a URL de health_raw (legado) ou usage_raw; só o usage_raw é usado.
    @usage_endpoint = endpoint.sub("health_raw", "usage_raw")
    # token embutido: gera um atalho já com o token (não assinado, servido só
    # pro app via API). Sem token: placeholder + pergunta no import (assinado).
    @token = token
  end

  def filename
    "Tempo-Tela-Life.shortcut"
  end

  def usage_url
    "#{@usage_endpoint}?period=yesterday&device=iphone&client_version=#{VERSION}"
  end

  def plist
    actions = [token_action] + screen_time_block
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>WFWorkflowName</key>
        <string>#{xml_escape(SHORTCUT_NAME)}</string>
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
          #{actions.join("\n")}
        </array>
      </dict>
      </plist>
    XML
  end

  private

  # Pergunta o token na importação e preenche a ação Texto do token (índice 0).
  # Com o token já embutido, não pergunta nada.
  def import_questions
    return "<array/>" unless @token.to_s.empty?

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
          <string>Cole seu token do Life / Paste your Life token</string>
          <key>DefaultValue</key>
          <string></string>
        </dict>
      </array>
    XML
  end

  def token_action
    text_action(TOKEN_UUID, @token.to_s)
  end

  def repeat_start_action(group_uuid, input_uuid)
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.repeat.each</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>WFControlFlowMode</key>
          <integer>0</integer>
          <key>GroupingIdentifier</key>
          <string>#{group_uuid}</string>
          <key>WFInput</key>
          #{output_variable(input_uuid, "Health Samples")}
        </dict>
      </dict>
    XML
  end

  def repeat_end_action(group_uuid, end_uuid)
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.repeat.each</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>WFControlFlowMode</key>
          <integer>2</integer>
          <key>GroupingIdentifier</key>
          <string>#{group_uuid}</string>
          <key>UUID</key>
          <string>#{end_uuid}</string>
          <key>CustomOutputName</key>
          <string>Repeat Results</string>
        </dict>
      </dict>
    XML
  end

  def combine_text_action(uuid, repeat_end_uuid)
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.text.combine</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>UUID</key>
          <string>#{uuid}</string>
          <key>WFTextSeparator</key>
          <string>New Lines</string>
          <key>WFInput</key>
          #{output_variable(repeat_end_uuid, "Repeat Results")}
        </dict>
      </dict>
    XML
  end

  # --- Bloco de Tempo de tela (App Intents) ---
  # Obter Atividade -> Repetir(Texto do item) -> Combinar -> POST /api/usage_raw.
  # Cada item da atividade é coagido a texto; o servidor parseia nome+duração.
  def screen_time_block
    [
      activity_action(ACT_UUID),
      repeat_start_action(ST_GROUP_UUID, ACT_UUID),
      activity_item_text_action(STX_UUID),
      repeat_end_action(ST_GROUP_UUID, ST_END_UUID),
      combine_text_action(SCOMB_UUID, ST_END_UUID),
      usage_post_action(SCOMB_UUID)
    ]
  end

  def activity_action(uuid)
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>#{ACTIVITY_ACTION_ID}</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>UUID</key>
          <string>#{uuid}</string>
          <key>during</key>
          <string>yesterday</string>
          <key>activityType</key>
          <string>app</string>
        </dict>
      </dict>
    XML
  end

  # Texto = o item atual do laço (entidade de atividade) coagido a texto.
  def activity_item_text_action(uuid)
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.gettext</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>UUID</key>
          <string>#{uuid}</string>
          <key>WFTextActionText</key>
          #{attachment_variable_token(OBJ.dup, REPEAT_ITEM_VAR)}
        </dict>
      </dict>
    XML
  end

  def usage_post_action(combine_uuid)
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.downloadurl</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>WFURL</key>
          <string>#{xml_escape(usage_url)}</string>
          <key>WFHTTPMethod</key>
          <string>POST</string>
          <key>WFHTTPHeaders</key>
          #{headers_field}
          <key>WFHTTPBodyType</key>
          <string>File</string>
          <key>WFRequestVariable</key>
          #{output_variable(combine_uuid, "Combined Text")}
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

  # Texto com UMA variável NOMEADA embutida (ex.: "Repeat Item").
  def attachment_variable_token(text, var_name)
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
              <key>Type</key>
              <string>Variable</string>
              <key>VariableName</key>
              <string>#{xml_escape(var_name)}</string>
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
