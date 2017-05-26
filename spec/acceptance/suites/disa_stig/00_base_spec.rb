require 'spec_helper_acceptance'

test_name 'auditd class'

describe 'auditd class' do
  hiera_backend = <<-EOM
---
:backends:
  - compliance_markup_enforce
  - yaml
:yaml:
  :datadir: "/etc/puppetlabs/code/hieradata"
:compliance_map:
  :datadir: "/etc/puppetlabs/code/hieradata"
:hierarchy:
  - default
:logger: console
  EOM

  let(:hieradata) {{
    'compliance_markup::enforcement_helper::profiles' => [ 'disa_stig' ]
  }}

  let(:manifest) {
    <<-EOS
      include compliance_markup::enforcement_helper
      include auditd
    EOS
  }

  def set_hiera_yaml_on(host)
    hiera_yaml = <<-EOM
---
:backends:
  - yaml
  - compliance_markup_enforce
:yaml:
  :datadir: "/etc/puppetlabs/code/hieradata"
:compliance_map:
  :datadir: "/etc/puppetlabs/code/hieradata"
:hierarchy:
  - default
:logger: console
    EOM

    Dir.mktmpdir do |dir|
      tmp_yaml = File.join(dir, 'hiera.yaml')
      File.open(tmp_yaml, 'w') do |fh|
        fh.puts hiera_yaml
      end

      host.do_scp_to(tmp_yaml, '/etc/puppetlabs/puppet/hiera.yaml', {})
    end
  end

  hosts.each do |host|
    context "on #{host}" do
      # Using puppet_apply as a helper
      it 'should work with no errors' do
        set_hieradata_on(host, hieradata)

        set_hiera_yaml_on(host)
        apply_manifest_on(host, manifest, :catch_failures => true)
      end
    end
  end
end
