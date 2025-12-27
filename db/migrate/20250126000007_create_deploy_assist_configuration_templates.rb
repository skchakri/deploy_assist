class CreateDeployAssistConfigurationTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :deploy_assist_configuration_templates, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, index: true
      t.string :name, null: false
      t.text :description
      t.integer :service_type, null: false
      t.jsonb :template_data, default: {}
      t.boolean :public, default: false

      t.timestamps
    end
  end
end
