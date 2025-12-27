class CreateDeployAssistWizardSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :deploy_assist_wizard_steps, id: :uuid do |t|
      t.references :service_configuration, null: false, foreign_key: { to_table: :deploy_assist_service_configurations }, type: :uuid
      t.string :step_key, null: false
      t.integer :step_number, null: false
      t.integer :status, default: 0
      t.jsonb :step_data, default: {}
      t.datetime :completed_at

      t.timestamps

      t.index [:service_configuration_id, :step_key], unique: true, name: 'index_wizard_steps_on_config_and_key'
    end
  end
end
