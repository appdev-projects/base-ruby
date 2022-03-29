FROM jelaniwoods/appdev2022-ruby-koans

WORKDIR /base-rails
COPY Gemfile /base-rails/Gemfile
COPY Gemfile.lock /base-rails/Gemfile.lock
# For some reason, the copied files were owned by root so bundle could not succeed
RUN /bin/bash -l -c "sudo chown -R $(whoami):$(whoami) Gemfile Gemfile.lock"
USER gitpod
# Pre-install gems in Gemfile
RUN /bin/bash -l -c "bundle install"
# Install Heroku
RUN /bin/bash -l -c "curl https://cli-assets.heroku.com/install.sh | sh"

USER gitpod
# Hack to make Gitpod find pre-installed gems
RUN echo "rvm use 3.0.0" >> ~/.bashrc
RUN echo "rvm_silence_path_mismatch_check_flag=1" >> ~/.rvmrc
# Add bin/ to PATH, so bin/server executes
RUN echo 'export PATH="$PATH:$GITPOD_REPO_ROOT/bin"' >> ~/.bashrc


# Git global configuration
RUN git config --global push.default upstream \
    && git config --global merge.ff only \
    && git config --global alias.acm '!f(){ git add -A && git commit -am "${*}"; };f' \
    && git config --global alias.as '!git add -A && git stash' \
    && git config --global alias.p 'push' \
    && git config --global alias.sla 'log --oneline --decorate --graph --all' \
    && git config --global alias.co 'checkout' \
    && git config --global alias.cob 'checkout -b'

# Alias 'git' to 'g'
RUN echo 'export PATH="$PATH:$GITPOD_REPO_ROOT/bin"' >> ~/.bashrc
RUN echo "# No arguments: 'git status'\n\
# With arguments: acts like 'git'\n\
g() {\n\
  if [[ \$# > 0 ]]; then\n\
    git \$@\n\
  else\n\
    git status\n\
  fi\n\
}\n# Complete g like git\n\
source /usr/share/bash-completion/completions/git\n\
__git_complete g __git_main" >> ~/.bash_aliases

# Add current git branch to bash prompt
RUN echo "# Add current git branch to prompt\n\
parse_git_branch() {\n\
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \\\(.*\\\)/:(\\\1)/'\n\
}\n\
\n\
PS1='\[]0;\u \w\]\[[01;32m\]\u\[[00m\] \[[01;34m\]\w\[[00m\]\[\e[0;38;5;197m\]\$(parse_git_branch)\[\e[0m\] \\\$ '" >> ~/.bashrc
