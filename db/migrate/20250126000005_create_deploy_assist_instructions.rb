class CreateDeployAssistInstructions < ActiveRecord::Migration[8.0]
  def change
    create_table :deploy_assist_instructions, id: :uuid do |t|
      t.references :service_configuration, null: false, foreign_key: { to_table: :deploy_assist_service_configurations }, type: :uuid
      t.integer :step_number, null: false
      t.string :title, null: false
      t.text :instruction_text
      t.string :instruction_type
      t.jsonb :data, default: {}
      t.boolean :completed, default: false
      t.datetime :completed_at

      t.timestamps

      t.index [:service_configuration_id, :step_number]
    end
  end
end
