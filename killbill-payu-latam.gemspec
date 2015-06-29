version = File.read(File.expand_path('../VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name        = 'killbill-payu-latam'
  s.version     = version
  s.summary     = 'Plugin to use PayU Latam as a gateway.'
  s.description = 'Kill Bill payment plugin for PayU Latam.'

  s.required_ruby_version = '>= 1.9.3'

  s.license = 'Apache License (2.0)'

  s.author   = 'Kill Bill core team'
  s.email    = 'killbilling-users@googlegroups.com'
  s.homepage = 'http://killbill.io'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.bindir        = 'bin'
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.rdoc_options << '--exclude' << '.'

  s.add_dependency 'killbill', '~> 4'

  s.add_dependency 'aktivemerchant', '~> 2.0.0'
  s.add_dependency 'koffsite_payments', '~> 3.0.0'

  s.add_dependency 'sinatra', '~> 1.3.4'
  s.add_dependency 'thread_safe', '~> 0.3.4'
  s.add_dependency 'activerecord', '~> 4.1.0'
  if defined?(JRUBY_VERSION)
    s.add_dependency 'activerecord-bogacs', '~> 0.3'
    s.add_dependency 'activerecord-jdbc-adapter', '~> 1.3', '< 1.5'
    s.add_dependency 'jruby-openssl', '~> 0.9.7'
  end
  s.add_dependency 'actionpack', '~> 4.1.0'
  s.add_dependency 'actionview', '~> 4.1.0'
  s.add_dependency 'monetize', '~> 1.1.0'
  s.add_dependency 'money', '~> 6.5.1'

  s.add_development_dependency 'jbundler', '~> 0.4.3'
  s.add_development_dependency 'rake', '>= 10.0.0'
  s.add_development_dependency 'rspec', '~> 2.12.0'
  if defined?(JRUBY_VERSION)
    s.add_development_dependency 'jdbc-sqlite3', '~> 3.7'
    s.add_development_dependency 'jdbc-mariadb', '~> 1.1'
  else
    s.add_development_dependency 'sqlite3', '~> 1.3.7'
  end
end
