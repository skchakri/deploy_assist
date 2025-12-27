class CreateDeployAssistCredentials < ActiveRecord::Migration[8.0]
  def change
    create_table :deploy_assist_credentials, id: :uuid do |t|
      t.references :deployment_setup, null: false, foreign_key: { to_table: :deploy_assist_deployment_setups }, type: :uuid
      t.string :service, null: false
      t.string :credential_type, null: false
      t.text :encrypted_value
      t.string :key_identifier
      t.boolean :active, default: true
      t.datetime :expires_at

      t.timestamps

      t.index [:deployment_setup_id, :service, :credential_type], name: 'index_credentials_on_setup_service_type'
    end
  end
end
