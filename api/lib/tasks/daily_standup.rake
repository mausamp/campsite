namespace :daily_standups do
  desc "Create daily standups post"

  task create: :environment do
    projects = ENV['DAILY_STANDUP_CHANNEL_ID']
    member_groups = ENV['DAILY_STANDUP_MEMBERS'].to_s.split(';')

    projects.split(',').each_with_index do |project_id, index|
      members = member_groups[index]
      mentions = members.split(',').map { |id| "<@#{id}>" }.join(' ')
      content = "What did you work on today?\n\n#{mentions}"
      project = Project.find_by(public_id: project_id)

      # Define current_organization as a method for MarkdownEnrichable
      define_singleton_method(:current_organization) { project.organization }

      include MarkdownEnrichable

      user = User.find_by(public_id: ENV['DAILY_STANDUP_USER_ID']) || User.first
      organization_membership = user.organization_memberships.find_by(organization: project.organization)

      post = Post::CreatePost.new(
              params: {
                description_html: markdown_to_html(content),
                title: Time.now.utc.strftime("%B %d, %Y"),
              },
              project: project,
              organization: current_organization,
              member: organization_membership,
              oauth_application: nil,
            ).run

      puts "Created post ##{post.id}"
    end
  end
end
