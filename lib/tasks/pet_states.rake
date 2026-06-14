namespace :pet_states do
  namespace :labeling do
    pct = ->(n, d) { d.zero? ? "n/a" : "#{(100.0 * n / d).round(2)}%" }

    desc "Validate the structural matcher with a hold-out over labeled states"
    task validate: :environment do
      labeled = PetState.usable.to_a
      shuffled = labeled.shuffle(random: Random.new(42))
      cut = (shuffled.size * 0.8).to_i
      train, test = shuffled[0...cut], shuffled[cut..]

      index = PetStateLabeling::AssetIndex.new(states: train)
      matcher = PetStateLabeling::StructuralMatcher.new(index)
      present = Hash.new { |h, k| h[k] = Set.new }
      train.each { |ps| present[ps.pet_type_id] << ps.pose }
      appearances = PetStateLabeling.appearances_for(test)

      buckets = Hash.new { |h, k| h[k] = [0, 0] } # confidence => [correct, wrong]
      confusion = Hash.new(0)                       # [actual, predicted] => count
      abstain = 0
      errors = []
      test.each do |ps|
        pred = matcher.predict(appearances[ps.id], present_poses: present[ps.pet_type_id])
        next (abstain += 1) if pred.nil?
        ok = pred.pose == ps.pose
        buckets[pred.confidence][ok ? 0 : 1] += 1
        confusion[[ps.pose, pred.pose]] += 1 unless ok
        errors << [ps.id, ps.pose, pred.pose, pred.confidence] if !ok && pred.confidence >= 0.95
      end

      decided = buckets.values.sum { |c, w| c + w }
      correct = buckets.values.sum(&:first)
      puts "Hold-out: #{test.size} test states (train #{train.size})"
      puts "Decided: #{decided} (#{pct.(decided, test.size)})  abstained: #{abstain}"
      puts "Accuracy on decided: #{pct.(correct, decided)}"
      puts
      puts "By confidence floor (cumulative):"
      cum_ok = cum_n = 0
      buckets.keys.sort.reverse.each do |conf|
        c, w = buckets[conf]
        cum_ok += c; cum_n += c + w
        puts "  >=#{conf}: bucket n=#{c + w} acc=#{pct.(c, c + w)}  | " \
             "cumulative cov=#{pct.(cum_n, test.size)} acc=#{pct.(cum_ok, cum_n)}"
      end
      puts
      puts "Confusion (actual -> predicted, errors only):"
      confusion.sort_by { |_, n| -n }.first(12).each do |(a, p), n|
        puts "  #{a} -> #{p}: #{n}"
      end
      puts
      puts "High-confidence (>=0.95) misses — eyeball as possible existing mislabels:"
      puts "  edit at /pet_types/<param>/pet_states/<id>/edit"
      errors.first(20).each { |id, a, p, c| puts "  PS ##{id}: labeled #{a}, predicted #{p} (#{c})" }
    end

    desc "Print a sample of live predictions with image URLs for visual spot-check"
    task report: :environment do
      sample = (ENV["SAMPLE"] || 30).to_i
      runner = PetStateLabeling::Runner.new(dry_run: true, limit: sample).run
      puts "Considered #{runner.tally[:considered]}, predicted #{runner.outcomes.size}, " \
           "abstained #{runner.tally[:abstained]}"
      puts
      runner.outcomes.each do |o|
        ps = o.pet_state
        ev = o.prediction.evidence
        puts "PS ##{ps.id}  #{ps.pet_type.human_name}"
        puts "  => #{o.prediction.pose}  (#{o.prediction.tier}, conf #{o.prediction.confidence})"
        puts "  evidence: #{ev.except(:eyes_poses, :mouth_moods).to_json}"
        [["eyes", ev[:eyes_asset_id]], ["mouth", ev[:mouth_asset_id]]].each do |label, aid|
          next unless aid
          puts "  #{label}: #{SwfAsset.find_by(id: aid)&.image_url}"
        end
      end
    end

    desc "Label the unlabeled backlog. Safe by default; set APPLY=1 to write. " \
         "Env: APPLY, LIMIT, TIER=structural|visual, MIN_CONFIDENCE"
    task run: :environment do
      apply = ENV["APPLY"] == "1"
      runner = PetStateLabeling::Runner.new(
        dry_run: !apply,
        limit: ENV["LIMIT"]&.to_i,
        only_tier: ENV["TIER"].presence,
        min_confidence: (ENV["MIN_CONFIDENCE"] || 0.8).to_f,
      ).run

      puts(apply ? "APPLIED:" : "DRY RUN (set APPLY=1 to write):")
      runner.tally.sort.each { |k, v| puts "  #{k}: #{v}" }
    end

    desc "Revert auto-applied labels. Env: SINCE='2026-06-07', DRY_RUN=1"
    task revert: :environment do
      audits = PetStateLabelAudit.all
      audits = audits.where("created_at >= ?", Time.zone.parse(ENV["SINCE"])) if ENV["SINCE"]
      dry = ENV["DRY_RUN"] == "1"
      reverted = skipped = 0
      audits.includes(:pet_state).find_each do |audit|
        ps = audit.pet_state
        # Only revert if the state still holds exactly what we applied (don't
        # clobber a human's later correction).
        if ps.labeled? && ps.mood_id == audit.mood_id && ps.female == audit.female
          unless dry
            PetState.transaction do
              ps.update!(pose: "UNKNOWN")
              audit.destroy!
            end
          end
          reverted += 1
        else
          skipped += 1
        end
      end
      puts(dry ? "DRY RUN:" : "Reverted:")
      puts "  reverted: #{reverted}  skipped (changed since): #{skipped}"
    end

  end
end
