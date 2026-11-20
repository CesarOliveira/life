# Linha do tempo de lugares: visitas (chegada/saída num ponto) vindas do iPhone
# (CLVisit) ou da importação da Linha do Tempo do Google, e os lugares que a
# pessoa nomeia ("Casa", "Academia"). Coordenadas e endereços são criptografados
# (Active Record Encryption), por isso ficam em colunas de texto e a distância é
# calculada em Ruby, não no banco.
class CreatePlacesAndVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :places do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :latitude, null: false
      t.text :longitude, null: false
      t.integer :radius_m, null: false, default: 120
      t.text :address
      t.timestamps
    end

    create_table :visits do |t|
      t.references :account, null: false, foreign_key: true
      t.references :place, foreign_key: { on_delete: :nullify }
      t.datetime :arrived_at, null: false
      t.datetime :departed_at
      t.date :date, null: false # dia local da chegada (para listar por dia)
      t.text :latitude, null: false
      t.text :longitude, null: false
      t.integer :accuracy_m
      t.text :address
      t.string :hint # sugestão de nome vinda da fonte (ex.: "HOME" do Google)
      t.string :source, null: false, default: "iphone"
      t.string :external_id, null: false
      t.timestamps
    end
    add_index :visits, [:account_id, :external_id], unique: true
    add_index :visits, [:account_id, :date]
    add_index :visits, [:account_id, :arrived_at]
  end
end
