class CreateAdmissions < ActiveRecord::Migration[5.0]
  def change
    create_table :admissions do |t|
      t.references    :chat_room  # 더 직관적으로 만들어줌 (외래키지정)
      t.references    :user

      t.timestamps
    end
  end
end
