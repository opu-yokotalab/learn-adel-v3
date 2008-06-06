class CreateEntTests < ActiveRecord::Migration
  def self.up
    create_table :ent_tests do |t|
      t.column :test_name, :string
      t.column :max_sum_point, :integer
    end
  end

  def self.down
    drop_table :ent_tests
  end
end
