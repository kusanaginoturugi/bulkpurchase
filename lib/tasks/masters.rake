# frozen_string_literal: true

namespace :masters do
  desc "Pull fellowships from osystem-masters and upsert into organizations"
  task sync: :environment do
    result = MasterSync.run
    puts "synced #{result.count} organizations (master updated_at=#{result.master_updated_at})"
  end
end
