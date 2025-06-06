require 'chef_helper'

RSpec.describe 'gitlab::gitlab-rails' do
  include_context 'gitlab-rails'

  describe 'GitLab Application Settings' do
    describe 'CDN Host' do
      context 'with default configuration' do
        it 'does not render cdn_host in gitlab.yml' do
          expect(gitlab_yml[:production][:gitlab][:cdn_host]).to be nil
        end
      end

      context 'with user specified configuration' do
        before do
          stub_gitlab_rb(
            gitlab_rails: {
              cdn_host: 'https://cdn.example.com'
            }
          )
        end

        it 'renders specified cdn_host in gitlab.yml' do
          expect(gitlab_yml[:production][:gitlab][:cdn_host]).to eq('https://cdn.example.com')
        end
      end
    end

    describe 'Content Security Policy settings' do
      context 'with default configuration' do
        it 'renders gitlab.yml without content security policy settings' do
          expect(gitlab_yml[:production][:gitlab][:content_security_policy]).to be nil
        end
      end

      context 'with user specified configuration' do
        context 'with content security policy disabled' do
          before do
            stub_gitlab_rb(
              gitlab_rails: {
                content_security_policy: {
                  enabled: false
                }
              }
            )
          end

          it 'renders gitlab.yml with content security policy disabled' do
            expect(gitlab_yml[:production][:gitlab][:content_security_policy]).to eq(
              enabled: false
            )
          end
        end

        context 'for various content security policy related settings' do
          before do
            stub_gitlab_rb(
              gitlab_rails: {
                content_security_policy: {
                  enabled: true,
                  report_only: true,
                  directives: {
                    default_src: "'self'",
                    script_src: "'self' http://recaptcha.net",
                    worker_src: "'self'"
                  }
                }
              }
            )
          end

          it 'renders gitlab.yml with user specified values for content security policy' do
            expect(gitlab_yml[:production][:gitlab][:content_security_policy]).to eq(
              enabled: true,
              report_only: true,
              directives: {
                default_src: "'self'",
                script_src: "'self' http://recaptcha.net",
                worker_src: "'self'"
              }
            )
          end
        end
      end
    end

    describe 'HTTP client settings' do
      context 'with default configuration' do
        it 'renders gitlab.yml with empty HTTP client settings' do
          expect(gitlab_yml[:production][:gitlab][:http_client]).to eq({})
        end
      end

      context 'with mutual TLS settings configured' do
        before do
          stub_gitlab_rb(
            gitlab_rails: {
              http_client: {
                tls_client_cert_file: '/path/to/tls_cert_file',
                tls_client_cert_password: 'somepassword'
              }
            }
          )
        end

        it 'renders gitlab.yml with HTTP client settings' do
          expect(gitlab_yml[:production][:gitlab][:http_client]).to eq(
            tls_client_cert_file: '/path/to/tls_cert_file',
            tls_client_cert_password: 'somepassword'
          )
        end
      end
    end

    describe 'SMIME email settings' do
      context 'with default configuration' do
        it 'renders gitlab.yml with SMIME email settings disabled' do
          expect(gitlab_yml[:production][:gitlab][:email_smime]).to eq(
            enabled: false,
            cert_file: '/etc/gitlab/ssl/gitlab_smime.crt',
            key_file: '/etc/gitlab/ssl/gitlab_smime.key',
            ca_certs_file: nil
          )
        end
      end

      context 'with user specified configuration' do
        before do
          stub_gitlab_rb(
            gitlab_rails: {
              gitlab_email_smime_enabled: true,
              gitlab_email_smime_key_file: '/etc/gitlab/ssl/custom_gitlab_smime.key',
              gitlab_email_smime_cert_file: '/etc/gitlab/ssl/custom_gitlab_smime.crt',
              gitlab_email_smime_ca_certs_file: '/etc/gitlab/ssl/custom_gitlab_smime_cas.crt'
            }
          )
        end

        it 'renders gitlab.yml with user specified values for SMIME email settings' do
          expect(gitlab_yml[:production][:gitlab][:email_smime]).to eq(
            enabled: true,
            cert_file: '/etc/gitlab/ssl/custom_gitlab_smime.crt',
            key_file: '/etc/gitlab/ssl/custom_gitlab_smime.key',
            ca_certs_file: '/etc/gitlab/ssl/custom_gitlab_smime_cas.crt'
          )
        end
      end
    end

    describe 'Allowed hosts' do
      context 'with default configuration' do
        it 'does not render allowed_hosts in gitlab.yml' do
          expect(gitlab_yml[:production][:gitlab][:allowed_hosts]).to be nil
        end
      end

      context 'with user specified configuration' do
        before do
          stub_gitlab_rb(
            gitlab_rails: {
              allowed_hosts: ['example.com', 'foobar.com']
            }
          )
        end

        it 'renders specified allowed_hosts in gitlab.yml' do
          expect(gitlab_yml[:production][:gitlab][:allowed_hosts]).to eq(['example.com', 'foobar.com'])
        end
      end
    end

    describe 'Application settings cache expiry' do
      context 'with default configuration' do
        it 'renders gitlab.yml without application settings cache expiry' do
          expect(gitlab_yml[:production][:gitlab][:application_settings_cache_seconds]).to be nil
        end
      end

      context 'with user specified configuration' do
        before do
          stub_gitlab_rb(
            gitlab_rails: {
              application_settings_cache_seconds: 30
            }
          )
        end

        it 'renders gitlab.yml with user specified value for application settings cache expiry' do
          expect(gitlab_yml[:production][:gitlab][:application_settings_cache_seconds]).to eq(30)
        end
      end
    end

    describe 'Maximum Request Duration' do
      context 'with default configuration' do
        it 'renders gitlab.yml with default value for maximum request duration' do
          expect(gitlab_yml[:production][:gitlab][:max_request_duration_seconds]).to eq(57)
        end

        context 'with default configuration and Unicorn as webserver' do
          before do
            stub_gitlab_rb(
              puma: { enable: false },
              unicorn: { enable: true }
            )
          end

          it 'renders gitlab.yml with default value for maximum request duration' do
            expect(gitlab_yml[:production][:gitlab][:max_request_duration_seconds]).to eq(57)
          end
        end
      end

      context 'with user specified configuration' do
        context 'for worker_timeout' do
          using RSpec::Parameterized::TableSyntax

          where(:web_worker, :configured_timeout, :expected_duration) do
            :unicorn | 30   | 29
            :unicorn | "30" | 29
            :puma    | 120  | 114
          end

          with_them do
            before do
              stub_gitlab_rb(
                unicorn: { enable: web_worker == :unicorn, worker_timeout: configured_timeout },
                puma: { enable: web_worker == :puma, worker_timeout: configured_timeout }
              )
            end

            it 'renders gitlab.yml with maximum request duration computed from configured worker timeout' do
              expect(gitlab_yml[:production][:gitlab][:max_request_duration_seconds]).to eq(expected_duration)
            end
          end
        end

        context 'for max_request_duration_seconds' do
          before do
            stub_gitlab_rb(
              puma: {
                worker_timeout: 120
              },
              gitlab_rails: {
                max_request_duration_seconds: 100
              }
            )
          end

          it 'renders gitlab.yml with user specified value for maximum request duration' do
            expect(gitlab_yml[:production][:gitlab][:max_request_duration_seconds]).to eq(100)
          end
        end
      end
    end

    describe 'Disable Animations' do
      context 'with default configuration' do
        it 'render gitlab.yml with default value for disable_animations' do
          expect(gitlab_yml[:production][:gitlab][:disable_animations]).to be false
        end
      end

      context 'with user specified configuration' do
        before do
          stub_gitlab_rb(
            gitlab_rails: {
              disable_animations: true
            }
          )
        end

        it 'render gitlab.yml with user specified value for disable_animations' do
          expect(gitlab_yml[:production][:gitlab][:disable_animations]).to be true
        end
      end
    end

    describe 'Change default theme settings' do
      context 'with default configuration' do
        it 'render gitlab.yml without default_color_mode' do
          expect(gitlab_yml[:production][:gitlab][:default_color_mode]).to be nil
        end
      end

      context 'with user specified configuration' do
        before do
          stub_gitlab_rb(
            gitlab_rails: {
              gitlab_default_color_mode: 2
            }
          )
        end

        it 'render gitlab.yml with user specified value for default_color_mode' do
          expect(gitlab_yml[:production][:gitlab][:default_color_mode]).to eq(2)
        end
      end
    end

    describe 'Product Usage Data' do
      context 'with default configuration' do
        it 'renders gitlab.yml with default value for initial_gitlab_product_usage_data' do
          expect(gitlab_yml[:production][:gitlab][:initial_gitlab_product_usage_data]).to be nil
        end
      end

      context 'with user specified configuration' do
        before do
          stub_gitlab_rb(
            gitlab_rails: {
              initial_gitlab_product_usage_data: false
            }
          )
        end

        it 'renders gitlab.yml with user specified value for initial_gitlab_product_usage_data' do
          expect(gitlab_yml[:production][:gitlab][:initial_gitlab_product_usage_data]).to be false
        end
      end
    end

    describe 'Session cookie salts' do
      context 'with default configuration' do
        it 'renders gitlab.yml with default values for cookie salts' do
          expect(gitlab_yml[:production][:gitlab][:signed_cookie_salt]).to be_nil
          expect(gitlab_yml[:production][:gitlab][:authenticated_encrypted_cookie_salt]).to be_nil
        end
      end

      context 'with user specified configuration' do
        before do
          stub_gitlab_rb(
            gitlab_rails: {
              signed_cookie_salt: 'custom_signed_salt',
              authenticated_encrypted_cookie_salt: 'custom_encrypted_salt'
            }
          )
        end

        it 'renders gitlab.yml with user specified values for cookie salts' do
          expect(gitlab_yml[:production][:gitlab][:signed_cookie_salt]).to eq('custom_signed_salt')
          expect(gitlab_yml[:production][:gitlab][:authenticated_encrypted_cookie_salt]).to eq('custom_encrypted_salt')
        end
      end
    end
  end
end
