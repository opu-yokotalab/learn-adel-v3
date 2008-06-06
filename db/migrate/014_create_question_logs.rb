class CreateQuestionLogs < ActiveRecord::Migration
  def self.up
    create_table :question_logs do |t|
      t.column :user_id, :integer
      t.column :ent_seq_id, :integer
      t.column :ent_module_id, :integer
      t.column :ent_test_id, :integer
      t.column :ent_question_id, :integer
      t.column :point, :integer
      t.column :created_on, :timestamp
    end
  end

  def self.down
    drop_table :question_logs
  end
end
