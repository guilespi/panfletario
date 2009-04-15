stages_glob = File.join(File.dirname(__FILE__), "deploy", "*")
stages = Dir[stages_glob].collect {|f| File.basename(f) }.sort
set :stages, stages

require 'capistrano/ext/multistage'
load 'config/cap-tasks/trike-tasks.rb'

set :scm, 'git'
set :repository, "git@github.com:tricycle/lesswrong.git"
set :git_enable_submodules, 1
set :deploy_via, :remote_cache
set :repository_cache, 'cached-copy'

# Be sure to change these in your application-specific files
set :branch, 'master'

set :user, "www-data"            # defaults to the currently logged in user
default_run_options[:pty] = true

namespace :deploy do
  task :after_update_code, :roles => [:web, :app] do
    %w[files assets].each {|dir| link_shared_dir(dir) }
  end

  def link_shared_dir(dir)
    shared_subdir = "#{deploy_to}/shared/#{dir}"
    public_dir = "#{release_path}/public/#{dir}"
    run "mkdir -p #{shared_subdir}"  # make sure the shared dir exists
    run "if [ -e #{public_dir} ]; then rm -rf #{public_dir} && echo '***\n*** #{public_dir} removed (in favour of a symlink to the shared version) ***\n***'; fi"
    run "ln -sv #{shared_subdir} #{public_dir}"
  end
 
  desc 'Link to a reddit ini file stored on the server (/usr/local/etc/reddit/#{application}.ini'
  task :symlink_remote_reddit_ini, :roles => [:app, :db] do
    run "ln -sf /usr/local/etc/reddit/#{application}.ini #{release_path}/r2/#{application}.ini"
  end

  desc 'Link to a robots.txt file stored on the server (/usr/local/etc/reddit/#{application}-robots.txt'
  task :symlink_remote_robots_txt, :roles => [:app, :db] do
    run "ln -sf /usr/local/etc/reddit/#{application}-robots.txt #{release_path}/r2/r2/public/robots.txt"
  end

  desc 'Run Reddit setup routine'
  task :setup_reddit, :roles => [:app] do
    sudo "/bin/bash -c \"cd #{release_path}/r2 && python ./setup.py install\""
    sudo "/bin/bash -c \"cd #{release_path} && chown -R #{user} .\""
  end

  desc "Restart the Application"
  task :restart, :roles => :app do
    pid_file = "#{shared_dir}/pids/paster.pid"
    run "cd #{deploy_to}/current/r2 && paster serve --stop-daemon --pid-file #{pid_file} #{application}.ini || true"
    run "cd #{deploy_to}/current/r2 && paster serve --daemon --pid-file #{pid_file} #{application}.ini"
  end
end

#before 'deploy:update_code', 'git:ensure_pushed'
#before 'deploy:update_code', 'git:ensure_deploy_branch'
#after "deploy:update_code", "deploy:symlink_remote_db_yaml"
#after "deploy:symlink", "deploy:apache:config"
after "deploy:update_code", "deploy:setup_reddit"
after "deploy:update_code", "deploy:symlink_remote_reddit_ini"
after "deploy:update_code", "deploy:symlink_remote_robots_txt"
