namespace :pets do
	desc "Load a pet's viewer data"
	task :load, [:name] => [:environment] do |task, args|
		pp Pet.fetch_viewer_data(args[:name])
	end
end
