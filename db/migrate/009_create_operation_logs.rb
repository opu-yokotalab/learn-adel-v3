class CreateOperationLogs < ActiveRecord::Migration
  def self.up
    create_table :operation_logs do |t|
      t.column :user_id, :integer
      t.column :ent_seq_id, :integer
      t.column :operation_code, :string
      t.column :event_arg, :string
      t.column :created_on, :timestamp
      t.column :dis_code, :integer
    end
  end

  def self.down
    drop_table :operation_logs
  end
end
