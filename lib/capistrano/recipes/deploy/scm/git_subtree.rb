require 'capistrano/recipes/deploy/scm/base'

module Capistrano
  module Deploy
    module SCM

      # An SCM module for using Git as your source control tool with Capistrano
      # 2.0.
      #
      # This module has been heavily adapted from the original capistrano Git module
      # in order to do subtree checkout more efficiently.
      #
      # Assumes you are using a shared Git repository.
      #
      # Parts of this plugin borrowed from Scott Chacon's version, which I
      # found on the Capistrano mailing list but failed to be able to get
      # working.
      #
      # FEATURES:
      #
      #   * Very simple, only requiring 2 lines in your deploy.rb.
      #   * Can deploy different branches, tags, or any SHA1 easily.
      #   * Supports prompting for password / passphrase upon checkout.
      #     (I am amazed at how some plugins don't do this)
      #   * Supports :scm_command, :scm_password, :scm_passphrase Capistrano
      #     directives.
      #
      # CONFIGURATION
      # -------------
      #
      # Use this plugin by adding the following line in your config/deploy.rb:
      #
      #   set :scm, :git_subtree
      #
      # Set <tt>:repository</tt> to the path of your Git repo:
      #
      #   set :repository, "someuser@somehost:/home/myproject"
      #
      # The above two options are required to be set, the ones below are
      # optional.
      #
      # You may set <tt>:branch</tt>, which is the reference to the branch, tag,
      # or any SHA1 you are deploying, for example:
      #
      #   set :branch, "master"
      #
      # Otherwise, HEAD is assumed.  I strongly suggest you set this.  HEAD is
      # not always the best assumption.
      #
      # The <tt>:scm_command</tt> configuration variable, if specified, will
      # be used as the full path to the git executable on the *remote* machine:
      #
      #   set :scm_command, "/opt/local/bin/git"
      #
      # For compatibility with deploy scripts that may have used the 1.x
      # version of this plugin before upgrading, <tt>:git</tt> is still
      # recognized as an alias for :scm_command.
      #
      # Set <tt>:scm_password</tt> to the password needed to clone your repo
      # if you don't have password-less (public key) entry:
      #
      #   set :scm_password, "my_secret'
      #
      # Otherwise, you will be prompted for a password.
      #
      # <tt>:scm_passphrase</tt> is also supported.
      #
      # For those that don't like to leave your entire repository on
      # your production server you can:
      #
      #   set :deploy_via, :export
      #
      # To deploy from a local repository:
      #
      #   set :repository, "file://."
      #   set :deploy_via, :copy
      #
      # AUTHORS
      # -------
      #
      # Barnaby Gray <barnaby@artirix.com>
      # Garry Dolley http://scie.nti.st
      # Contributions by Geoffrey Grosenbach http://topfunky.com
      #              Scott Chacon http://jointheconversation.org
      #                          Alex Arnell http://twologic.com
      #                                   and Phillip Goldenburg

      class GitSubtree < Base
        # Sets the default command name for this SCM on your *local* machine.
        # Users may override this by setting the :scm_command variable.
        default_command "git"

        # When referencing "head", use the branch we want to deploy or, by
        # default, Git's reference of HEAD (the latest changeset in the default
        # branch, usually called "master").
        def head
          variable(:branch) || 'HEAD'
        end

        def origin
          variable(:remote) || 'origin'
        end

        # Archives from the current subdirectory from local copy.
        def checkout(revision, destination)
          git    = command

          args = []
          args << "--format=tar"
          #tarball = "#{destination}.tar"
          #args << "--output=#{tarball}"

          execute = []
          execute << "#{git} archive #{verbose} #{args.join(' ')} #{revision} | (mkdir -p #{destination} && cd #{destination} && tar xf -)"
          #execute << "tar xf #{tarball}"

          if variable(:git_enable_submodules)
            execute << "#{git} submodule #{verbose} init"
            execute << "#{git} submodule #{verbose} sync"
            execute << "#{git} submodule #{verbose} update"
          end

          if variable(:git_post_checkout)
            # any commands to run in the exported copy before packaging
            execute << "(#{(["cd #{destination}"] + variable(:git_post_checkout)).join(' && ')})"
          end

          execute.join(" && ")
        end
        
        # Just does a checkout as above.
        def export(revision, destination)
          checkout(revision, destination)
        end
        
        # Returns a string of diffs between two revisions
        def diff(from, to=nil)
          from << "..#{to}" if to
          scm :diff, from
        end

        # Returns a log of changes between the two revisions (inclusive).
        def log(from, to=nil)
          scm :log, "#{from}..#{to}"
        end

        # Getting the actual commit id, in case we were passed a tag
        # or partial sha or something - it will return the sha if you pass a sha, too
        def query_revision(revision)
          raise ArgumentError, "Deploying remote branches is no longer supported.  Specify the remote branch as a local branch for the git repository you're deploying from (ie: '#{revision.gsub('origin/', '')}' rather than '#{revision}')." if revision =~ /^origin\//
          return revision if revision =~ /^[0-9a-f]{40}$/
          command = scm('ls-remote', repository, revision)
          result = yield(command)
          revdata = result.split(/[\t\n]/)
          newrev = nil
          revdata.each_slice(2) do |refs|
            rev, ref = *refs
            if ref.sub(/refs\/.*?\//, '').strip == revision.to_s
              newrev = rev
              break
            end
          end
          raise "Unable to resolve revision for '#{revision}' on repository '#{repository}'." unless newrev =~ /^[0-9a-f]{40}$/
          return newrev
        end

        def command
          # For backwards compatibility with 1.x version of this module
          variable(:git) || super
        end

        # Determines what the response should be for a particular bit of text
        # from the SCM. Password prompts, connection requests, passphrases,
        # etc. are handled here.
        def handle_data(state, stream, text)
          host = state[:channel][:host]
          logger.info "[#{host} :: #{stream}] #{text}"
          case text
          when /\bpassword.*:/i
            # git is prompting for a password
            unless pass = variable(:scm_password)
              pass = Capistrano::CLI.password_prompt
            end
            "#{pass}\n"
          when %r{\(yes/no\)}
            # git is asking whether or not to connect
            "yes\n"
          when /passphrase/i
            # git is asking for the passphrase for the user's key
            unless pass = variable(:scm_passphrase)
              pass = Capistrano::CLI.password_prompt
            end
            "#{pass}\n"
          when /accept \(t\)emporarily/
            # git is asking whether to accept the certificate
            "t\n"
          end
        end

        private

          # If verbose output is requested, return nil, otherwise return the
          # command-line switch for "quiet" ("-q").
          def verbose
            variable(:scm_verbose) ? '-v' : nil
          end
      end
    end
  end
end
