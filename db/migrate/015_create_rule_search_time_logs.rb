class CreateRuleSearchTimeLogs < ActiveRecord::Migration
  def self.up
    create_table :rule_search_time_logs do |t|
      t.column :user_id, :integer
      t.column :time_name, :string
      t.column :time_value, :time
    end
  end

  def self.down
    drop_table :rule_search_time_logs
  end
end
