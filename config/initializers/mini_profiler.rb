# O medidor de desempenho de desenvolvimento não aparece dentro do app nativo
# (atrapalha capturas de tela e testes no simulador).
if defined?(Rack::MiniProfiler)
  Rack::MiniProfiler.config.pre_authorize_cb = ->(env) { !env["HTTP_USER_AGENT"].to_s.include?("LifeApp/") }
end
