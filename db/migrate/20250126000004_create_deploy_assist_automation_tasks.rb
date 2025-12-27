class CreateDeployAssistAutomationTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :deploy_assist_automation_tasks, id: :uuid do |t|
      t.references :service_configuration, null: false, foreign_key: { to_table: :deploy_assist_service_configurations }, type: :uuid
      t.string :task_type, null: false
      t.integer :status, default: 0
      t.text :description
      t.jsonb :task_params, default: {}
      t.jsonb :task_result, default: {}
      t.text :error_message
      t.datetime :executed_at

      t.timestamps

      t.index [:service_configuration_id, :status]
    end
  end
end
