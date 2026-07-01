require "rails_helper"

RSpec.describe ExamCatalog do
  it "maps canonical keys to a panel and PT label" do
    ast = described_class.meta("ast")
    expect(ast[:label]).to eq("TGO / AST")
    expect(ast[:panel]).to eq("funcao_hepatica")
    expect(described_class.meta("hemoglobina")[:panel]).to eq("hemograma")
  end

  it "lists aliases in the extractor reference" do
    ref = described_class.prompt_reference
    expect(ref).to include("ast:")
    expect(ref).to include("tgo")   # apelido
    expect(ref).to include("Hemograma")
  end

  it "groups measurement-groups by panel, in panel order, with Outros last" do
    groups = [
      { key: "glucose", label: "Glicose" },
      { key: "hemoglobina", label: "Hemoglobina" },
      { key: "algo_desconhecido", label: "Algo" }
    ]
    panels = described_class.group(groups)
    labels = panels.map { |p| p[:key] }
    expect(labels.first).to eq("hemograma")      # hemograma vem antes de glicemia
    expect(labels).to include("glicemia")
    expect(labels.last).to eq("outros")          # desconhecido cai em Outros, por último
  end
end
