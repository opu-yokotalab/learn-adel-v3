class CreateEntQuestions < ActiveRecord::Migration
  def self.up
    create_table :ent_questions do |t|
      t.column :question_name, :string
      t.column :max_point, :integer
    end
  end

  def self.down
    drop_table :ent_questions
  end
end
