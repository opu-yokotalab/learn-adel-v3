class CreateEntModules < ActiveRecord::Migration
  def self.up
    create_table :ent_modules do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :ent_modules
  end
end
