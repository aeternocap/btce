class CreateTrades < ActiveRecord::Migration
  def change
    create_table :trades do |t|
      t.references :strategy
      t.timestamp :begin
      t.timestamp :end
      t.decimal :initial_usd, scale: 12, precision: 24
      t.decimal :usd, scale: 12, precision: 24
      t.decimal :btc, scale: 12, precision: 24
      t.decimal :estimate_usd, scale: 12, precision: 24
      t.decimal :estimate_btc, scale: 12, precision: 24
      t.decimal :profit_rate, scale: 2, precision: 4
      t.text :options
    end
  end
end
