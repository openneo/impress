class CreatePetStateLabelAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :pet_state_label_audits, charset: "utf8mb4",
        collation: "utf8mb4_unicode_520_ci" do |t|
      t.references :pet_state, type: :integer, null: false, foreign_key: true

      # The label we applied, stored redundantly so the audit is self-contained
      # even if the pet state is later relabeled.
      t.string :pose, null: false
      t.integer :mood_id
      t.boolean :female

      # How we decided: "structural", "visual", or "visual_guess" (a deterministic
      # gender guess for a true duplicate-asset pet, e.g. Robot/Varwolf).
      t.string :tier, null: false
      t.float :confidence

      # JSON blob of supporting evidence (matched asset ids, distances, candidate
      # poses, margins). Stored as text + serialized in the model, matching the
      # repo's convention of avoiding native json columns.
      t.text :evidence

      t.datetime :created_at, null: false
    end
  end
end
