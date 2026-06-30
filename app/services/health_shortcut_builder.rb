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
# "Cano burro": o atalho NÃO calcula nada. Para cada métrica, percorre as
# amostras, extrai só o número (Obter Detalhes -> Valor, lendo o Item de
# Repetição), junta um por linha e envia. O Rails (/api/health_raw) agrega.
#
# IMPORTANTE (iOS): enviar dados de Saúde p/ URL exige
# Ajustes -> Atalhos -> Avançado -> "Permitir o Compartilhamento de Grandes
# Quantidades de Dados". Sem isso o iOS bloqueia ("compartilhar N itens da Saúde").
#
# Ordem por métrica: [Localizar] -> [Repetir: Obter Valor] -> [Combinar Repeat
# Results] -> [POST]. Uma ação Texto (token) no início serve a todos os POSTs.
class HealthShortcutBuilder
  # Marcador de versão: vai na query ("client_version"); o servidor devolve na
  # resposta. Bumpe a cada build p/ confirmar que NÃO baixou arquivo cacheado.
  VERSION = "v10".freeze

  TOKEN_UUID = "11111111-1111-1111-1111-111111111111".freeze
  REPEAT_ITEM_VAR = "Repeat Item".freeze # nome interno (inglês) do item do laço
  OBJ = "\u{FFFC}".freeze # placeholder de anexo (object replacement char)
  TOKEN_ACTION_INDEX = 0 # a ação Texto do token é a primeira

  # Métricas coletadas. `type` é o rótulo do tipo no seletor da Saúde.
  # `property` é o detalhe extraído de cada amostra ("Value", "Start Date"...).
  # `suffix` torna os UUIDs únicos por bloco (precisa ser 1 hex).
  # Sono: enviamos início e fim de cada amostra; o Rails calcula dormiu (menor
  # início), acordou (maior fim) e horas dormidas (acordou - dormiu).
  METRICS = [
    { key: "steps", type: "Steps", property: "Value", suffix: "a" },
    { key: "resting_hr", type: "Resting Heart Rate", property: "Value", suffix: "b" },
    { key: "sleep_start", type: "Sleep", property: "Start Date", suffix: "c" },
    { key: "sleep_end", type: "Sleep", property: "End Date", suffix: "d" }
  ].freeze

  def initialize(endpoint:)
    @endpoint = endpoint
  end

  def filename
    "Saude-Life.shortcut"
  end

  def post_url(key)
    "#{@endpoint}?key=#{key}&period=today&client_version=#{VERSION}"
  end

  def plist
    actions = [token_action] + METRICS.flat_map { |m| metric_block(m) }
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
          #{actions.join("\n")}
        </array>
      </dict>
      </plist>
    XML
  end

  private

  # UUIDs determinísticos por bloco (o sufixo de 1 hex garante unicidade).
  def uuids(suffix)
    {
      find: "2222222#{suffix}-2222-2222-2222-222222222222",
      group: "4444444#{suffix}-4444-4444-4444-444444444444",
      detail: "5555555#{suffix}-5555-5555-5555-555555555555",
      repeat_end: "6666666#{suffix}-6666-6666-6666-666666666666",
      combine: "3333333#{suffix}-3333-3333-3333-333333333333"
    }
  end

  # Pergunta o token na importação e preenche a ação Texto do token (índice 0).
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

  def token_action
    text_action(TOKEN_UUID, "")
  end

  # Bloco completo de uma métrica: Localizar -> Repetir(Obter Valor) ->
  # Combinar(Repeat Results) -> POST.
  def metric_block(metric)
    u = uuids(metric[:suffix])
    [
      health_find_action(u[:find], type_label: metric[:type]),
      repeat_start_action(u[:group], u[:find]),
      detail_value_action(u[:detail], metric.fetch(:property, "Value")),
      repeat_end_action(u[:group], u[:repeat_end]),
      combine_text_action(u[:combine], u[:repeat_end]),
      post_action(metric[:key], u[:combine])
    ]
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

  # Obter Detalhes -> propriedade do Item de Repetição (Valor/Início/Fim).
  # Leitura, não cálculo.
  def detail_value_action(uuid, property)
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.properties.health.quantity</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>UUID</key>
          <string>#{uuid}</string>
          <key>WFContentItemPropertyName</key>
          <string>#{xml_escape(property)}</string>
          <key>WFInput</key>
          #{named_variable(REPEAT_ITEM_VAR)}
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

  def post_action(key, combine_uuid)
    <<~XML
      <dict>
        <key>WFWorkflowActionIdentifier</key>
        <string>is.workflow.actions.downloadurl</string>
        <key>WFWorkflowActionParameters</key>
        <dict>
          <key>WFURL</key>
          <string>#{xml_escape(post_url(key))}</string>
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

  # Referência a uma variável NOMEADA (ex.: "Repeat Item").
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
