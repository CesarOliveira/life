# TEMP: despeja os últimos logs de ingestão de saúde p/ diagnóstico (revertido
# no próximo deploy). Só números/datas de saúde — sem tokens.
logs = IngestionLog.where(endpoint: "health_raw").order(created_at: :desc).limit(12)
puts "INGEST_DUMP_START count=#{logs.size}"
logs.each do |l|
  body = l.raw_body.to_s
  lines = body.split(/[\r\n]+/)
  puts "INGEST| at=#{l.created_at.iso8601} key=#{l.query['key']} period=#{l.query['period']} ver=#{l.client_version} status=#{l.status} result=#{l.result.to_json} nlines=#{lines.size}"
  puts "INGEST|   head=#{lines.first(4).inspect}"
  puts "INGEST|   tail=#{lines.last(2).inspect}"
end
puts "INGEST_DUMP_END"
