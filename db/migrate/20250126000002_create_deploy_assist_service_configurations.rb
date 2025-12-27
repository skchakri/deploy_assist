class CreateDeployAssistServiceConfigurations < ActiveRecord::Migration[8.0]
  def change
    create_table :deploy_assist_service_configurations, id: :uuid do |t|
      t.references :deployment_setup, null: false, foreign_key: { to_table: :deploy_assist_deployment_setups }, type: :uuid
      t.integer :service_type, null: false
      t.integer :status, default: 0
      t.integer :completion_percentage, default: 0
      t.jsonb :collected_data, default: {}
      t.jsonb :automation_results, default: {}
      t.text :error_message
      t.datetime :completed_at

      t.timestamps

      t.index [:deployment_setup_id, :service_type], unique: true, name: 'index_service_config_on_setup_and_type'
    end
  end
end
