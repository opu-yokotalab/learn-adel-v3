class CreateEntSeqs < ActiveRecord::Migration
  def self.up
    create_table :ent_seqs do |t|
      t.column :seq_src, :text
      t.column :seq_title, :string
    end
  end

  def self.down
    drop_table :ent_seqs
  end
end
