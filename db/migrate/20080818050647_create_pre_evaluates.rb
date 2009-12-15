class CreatePreEvaluates < ActiveRecord::Migration
  def self.up
    create_table :pre_evaluates do |t|
      t.integer :chk_selection
      t.integer :eval_result
      t.integer :total_point
      t.boolean :comp_eval
      t.integer :crct_total_weight
      t.integer :incrct_total_weight
      t.integer :total_weight
      t.string :eval_key
      t.string :evaluate_pkey

      t.timestamps
    end
  end

  def self.down
    drop_table :pre_evaluates
  end
end
