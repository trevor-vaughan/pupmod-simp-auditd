require 'spec_helper_acceptance'
require 'json'

test_name 'Validate Compliance'

describe 'use inspec to check compliance' do

  package_matrix = {
    'RedHat' => {
      '6' => {
        'package' => 'https://packages.chef.io/files/stable/inspec/1.25.1/el/6/inspec-1.25.1-1.el6.x86_64.rpm'
      },
      '7' => {
        'package' => 'https://packages.chef.io/files/stable/inspec/1.25.1/el/7/inspec-1.25.1-1.el7.x86_64.rpm'
      }
    },
    'CentOS' => {
      '6' => {
        'package' => 'https://packages.chef.io/files/stable/inspec/1.25.1/el/6/inspec-1.25.1-1.el6.x86_64.rpm'
      },
      '7' => {
        'package' => 'https://packages.chef.io/files/stable/inspec/1.25.1/el/7/inspec-1.25.1-1.el7.x86_64.rpm'
      }
    }
  }

  profiles_to_validate = ['disa_stig']

  profile_dir = '/tmp/inspec_tests'

  hosts.each do |host|
    profiles_to_validate.each do |profile|
      context "for profile #{profile}" do

        let(:timestamp) { Time.now.to_i }

        context "on #{host}" do
          os = fact_on(host, 'operatingsystem')
          os_rel = fact_on(host, 'operatingsystemmajrelease')

          package_matrix.keys.each do |operatingsystem|
            if os == operatingsystem
              context "on #{operatingsystem}" do
                package_matrix[operatingsystem].keys.each do |release|
                  if os_rel == release
                    it 'should have inspec installed' do
                      host.install_package(package_matrix[operatingsystem][release]['package'])
                    end

                    it "should copy over the #{profile} inspec profile" do
                      scp_to(host, "spec/fixtures/inspec/#{operatingsystem}_#{release}_#{profile}", profile_dir)
                    end

                    it 'should run inspec and export results' do
                      json_output = on(host, "inspec exec --format json #{profile_dir}", :silent => true).stdout.strip

                      # Strip off garbage
                      json_output = json_output[json_output.index(/{"/)..-1]

                      File.open("inspec_json-#{timestamp}.log", 'w') { |file|
                        #file.write(JSON.pretty_generate(json_output))
                        file.write(json_output)
                      }
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
