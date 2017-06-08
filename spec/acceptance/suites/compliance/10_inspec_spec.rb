require 'spec_helper_acceptance'
require 'json'

test_name 'Validate Compliance'

describe 'use inspec to check compliance' do

  profiles_to_validate = ['disa_stig']

  profile_dir = '/tmp/inspec_tests'
  output_dir  = File.absolute_path('inspec_results')
  timestamp   = Time.now.to_i

  def process_inspec_results(inspec_results)
    require 'highline'

    HighLine.colorize_strings

    stats = {
      :passed => 0,
      :failed => 0,
      :report => []
    }

    profiles = inspec_results['profiles']

    profiles.each do |profile|
      stats[:report] << "Name: #{profile['name']}"

      profile['controls'].each do |control|
        title = control['title']
        if title.length > 72
          title = title[0..71] + '(...)'
        end

        title_chunks = control['title'].scan(/.{1,72}\W|.{1,72}/).map(&:strip)

        stats[:report] << "\n  Control: #{title_chunks.shift}"
        unless title_chunks.empty?
          title_chunks.map!{|x| x = "           #{x}"}
          stats[:report] << title_chunks.join("\n")
        end

        status = control['results'].first['status']

        status_str = "    Status: "
        if status =~ /^fail/
          stats[:failed] += 1

          stats[:report] << status_str + status.red
          stats[:report] << "    File: #{control['source_location']['ref']}"
        else
          stats[:passed] += 1

          stats[:report] << status_str + status.green
        end
      end

      stats[:report] << "\n  Statistics:"
      stats[:report] << "    * Passed: #{stats[:passed].to_s.green}"
      stats[:report] << "    * Failed: #{stats[:failed].to_s.red}"
      stats[:report] << "    * Score:  #{((stats[:passed].to_f/(stats[:passed] + stats[:failed])) * 100.0).round(0)}%"
    end

    stats[:report] = stats[:report].join("\n")

    return stats
  end

  before(:each) do
    unless File.directory?(output_dir)
      FileUtils.mkdir(output_dir)
    end
  end

  hosts.each do |host|
    profiles_to_validate.each do |profile|
      context "for profile #{profile}" do

        let(:inspec_results) { File.join(output_dir, "#{host.hostname}-inspec-#{timestamp}") }

        context "on #{host}" do
          os = fact_on(host, 'operatingsystem')
          os_rel = fact_on(host, 'operatingsystemmajrelease')

          it 'should have inspec installed' do
            host.install_package('inspec')
          end

          it "should copy over the #{profile} inspec profile" do
            scp_to(host, "spec/fixtures/inspec/#{os}_#{os_rel}_#{profile}", profile_dir)
          end

          it 'should run inspec and export results' do
            on(host, "inspec exec --format json #{profile_dir} > /tmp/inspec_results.json", :silent => true)

            tmpdir = Dir.mktmpdir
            begin
              Dir.chdir(tmpdir) do
                scp_from(host, '/tmp/inspec_results.json', '.')

                File.open(inspec_results + '.json', 'w') do |fh|
                  inspec_json = JSON.load(File.read('inspec_results.json'))
                  fh.puts(JSON.pretty_generate(inspec_json))
                end
              end
            ensure
              FileUtils.remove_entry_secure tmpdir
            end
          end

          it 'should not have any failing tests' do
            inspec_report = process_inspec_results(JSON.load(File.read(inspec_results + '.json')))

            File.open(inspec_results + '.report', 'w') do |fh|
              fh.puts(inspec_report[:report].uncolor)
            end

            if inspec_report[:failed] > 0
              puts inspec_report[:report]
            end

            expect( inspec_report[:failed] ).to eq(0)
          end
        end
      end
    end
  end
end
