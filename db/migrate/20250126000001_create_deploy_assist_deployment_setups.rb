class CreateDeployAssistDeploymentSetups < ActiveRecord::Migration[8.0]
  def change
    create_table :deploy_assist_deployment_setups, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, index: true
      t.string :app_name
      t.string :environment, null: false, default: 'production'
      t.string :domain
      t.string :region, default: 'us-east-1'
      t.jsonb :metadata, default: {}
      t.integer :setup_status, default: 0
      t.datetime :setup_completed_at

      t.timestamps

      t.index [:user_id, :environment]
    end
  end
end
