class CreateLearns < ActiveRecord::Migration
  def self.up
    create_table :learns do |t|
      t.string :name
      t.string :contents

      t.timestamps
    end
  end

  def self.down
    drop_table :learns
  end
end
