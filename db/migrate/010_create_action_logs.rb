class CreateActionLogs < ActiveRecord::Migration
  def self.up
    create_table :action_logs do |t|
      t.column :user_id, :integer
      t.column :ent_seq_id, :integer
      t.column :action_code, :string
      t.column :action_value, :string
      t.column :created_on, :timestamp
      t.column :dis_code, :integer
    end
  end

  def self.down
    drop_table :action_logs
  end
end
