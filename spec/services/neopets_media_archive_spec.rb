require 'webmock/rspec'
require_relative '../rails_helper'

RSpec.describe NeopetsMediaArchive do
	let(:manifest_url) { "https://images.neopets.com/cp/bio/data/000/000/053/53771_655df6dbe0/manifest.json" }
	let(:manifest) { '{"cpmanifest":{"part_id":"53771","assets":[{"asset_data":[]}],"applied_formats":["lod"]}}' }
	let(:truncated_manifest) { manifest[0, 70] } # Ends mid-string, like the real bug.

	before do
		@archive_dir = Dir.mktmpdir
		stub_const("NeopetsMediaArchive::ROOT_PATH", Pathname.new(@archive_dir))
	end
	after { FileUtils.remove_entry(@archive_dir) }

	let(:local_path) { NeopetsMediaArchive.local_file_path(manifest_url) }

	# Fake an origin response whose body doesn't match its declared length, which
	# WebMock can't express (it derives the length from the body it's given).
	def stub_origin_response(declared_length:, body:)
		response = double("response", status: 200,
			body: double("body", length: declared_length), read: body)
		allow(DTIRequests).to receive(:get).with(manifest_url).and_yield(response)
	end

	describe ".load_file" do
		it "downloads and caches a complete file" do
			stub_request(:get, manifest_url).to_return(body: manifest)

			result = NeopetsMediaArchive.load_file(manifest_url)

			expect(result).to eq({content: manifest, source: "network"})
			expect(File.binread(local_path)).to eq(manifest)
		end

		it "raises and caches nothing when the body is shorter than declared" do
			stub_origin_response(declared_length: manifest.bytesize,
				body: truncated_manifest)

			expect { NeopetsMediaArchive.load_file(manifest_url) }.
				to raise_error(NeopetsMediaArchive::IncompleteResponse)
			expect(File.exist?(local_path)).to be false
		end

		it "accepts a body when no length is declared" do
			stub_origin_response(declared_length: nil, body: manifest)

			expect(NeopetsMediaArchive.load_file(manifest_url)[:content]).
				to eq(manifest)
		end

		it "leaves no temporary files behind" do
			stub_request(:get, manifest_url).to_return(body: manifest)

			NeopetsMediaArchive.load_file(manifest_url)

			expect(local_path.dirname.children).to eq([local_path])
		end

		it "skips the cached copy and overwrites it when refreshing" do
			local_path.dirname.mkpath
			File.binwrite(local_path, truncated_manifest)
			stub_request(:get, manifest_url).to_return(body: manifest)

			result = NeopetsMediaArchive.load_file(manifest_url, refresh: true)

			expect(result).to eq({content: manifest, source: "network"})
			expect(File.binread(local_path)).to eq(manifest)
		end
	end

	describe "SwfAsset#load_manifest" do
		let(:asset) { SwfAsset.new(manifest_url: manifest_url) }

		it "re-downloads a cached manifest that fails to parse, healing the cache" do
			local_path.dirname.mkpath
			File.binwrite(local_path, truncated_manifest)
			stub_request(:get, manifest_url).to_return(body: manifest)

			parsed = asset.load_manifest(save_changes: false)

			expect(parsed.dig("cpmanifest", "part_id")).to eq("53771")
			expect(File.binread(local_path)).to eq(manifest)
		end

		it "gives up if the origin's copy doesn't parse either" do
			local_path.dirname.mkpath
			File.binwrite(local_path, truncated_manifest)
			stub_request(:get, manifest_url).to_return(body: truncated_manifest)

			expect(asset.load_manifest(save_changes: false)).to be_nil
			expect(WebMock).to have_requested(:get, manifest_url).once
		end

		it "returns nil without caching on an incomplete response" do
			stub_origin_response(declared_length: manifest.bytesize,
				body: truncated_manifest)

			expect(asset.load_manifest(save_changes: false)).to be_nil
			expect(File.exist?(local_path)).to be false
		end
	end
end
