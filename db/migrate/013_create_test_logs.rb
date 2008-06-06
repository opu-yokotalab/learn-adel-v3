class CreateTestLogs < ActiveRecord::Migration
  def self.up
    create_table :test_logs do |t|
      t.column :user_id, :integer
      t.column :ent_seq_id, :integer
      t.column :ent_module_id, :integer
      t.column :ent_test_id, :integer
      t.column :sum_point, :integer
      t.column :created_on, :timestamp
    end
  end

  def self.down
    drop_table :test_logs
  end
end
