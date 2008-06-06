class CreateEntModules < ActiveRecord::Migration
  def self.up
    create_table :ent_modules do |t|
      t.column :module_name, :string
      t.column :module_src, :text
    end
  end

  def self.down
    drop_table :ent_modules
  end
end
