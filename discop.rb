require 'discordrb'
require 'yaml'
require 'rubocop'

CHANNEL_ID = 83_281_822_225_530_880
RUBOCOP_EMOTE = 'rubocop%3A246708457460334592'.freeze
PASS_EMOTE = 'helYea%3A236243426662678528'.freeze
FAIL_EMOTE = 'helNa%3A239120424938504192'.freeze
DELETE_EMOTE = '❌'.freeze

@secrets = YAML.load_file('secret.yml')
bot = Discordrb::Bot.new token: @secrets[:token]

def rubocop_this(team, text)
  processed = RuboCop::ProcessedSource.new(text, 2.4)
  offenses = team.inspect_file(processed)
  offenses.collect do |o|
    l = o.location
    c = o.severity.code
    line = l.line == l.last_line
    "**L#{l.line}:#{l.column + 1}: #{c}:** *#{o.message}*\n```ruby\n#{l.source_line}#{' ...' unless line}\n#{' ' * l.column + '^' * (line ? l.last_column - l.column : l.source_line.length - l.column)}```"
  end.join("\n")
end

def my_cops
  RuboCop::Cop::Cop.non_rails -
      [
          RuboCop::Cop::Metrics::AbcSize,
          RuboCop::Cop::Metrics::BlockNesting,
          RuboCop::Cop::Metrics::BlockLength,
          RuboCop::Cop::Metrics::ClassLength,
          RuboCop::Cop::Metrics::CyclomaticComplexity,
          RuboCop::Cop::Metrics::LineLength,
          RuboCop::Cop::Metrics::MethodLength,
          RuboCop::Cop::Metrics::ModuleLength,
          RuboCop::Cop::Metrics::ParameterLists,
          RuboCop::Cop::Metrics::PerceivedComplexity,
          RuboCop::Cop::Style::Alias,
          RuboCop::Cop::Style::ClassAndModuleChildren,
          RuboCop::Cop::Style::Documentation,
          RuboCop::Cop::Style::FileName,
          RuboCop::Cop::Style::TrailingBlankLines,
      ]
end

bot.message(in: CHANNEL_ID) do |event|
  next unless event.content =~ /```(?:ruby|rb)\n[\s\S]+```/i
  event.message.react(RUBOCOP_EMOTE)
  reply = []
  event.content.scan(/```(?:ruby|rb)\n([\s\S]+?)```/i).each do |ruby_code|
    config = RuboCop::ConfigLoader.default_configuration
    team = RuboCop::Cop::Team.new(my_cops, config)
    message = rubocop_this(team, ruby_code[0])
    unless message.empty?
      event.message.react(FAIL_EMOTE) if reply.empty?
      reply << message
    end
  end
  if reply.empty?
    event.message.react(PASS_EMOTE)
  else
    message = event.channel.send_embed(event.user.mention) do |embed|
      embed.author = Discordrb::Webhooks::EmbedAuthor.new(name: 'RuboCop', url: 'https://github.com/bbatsov/rubocop', icon_url: 'https://gratipay.com/rubocop/image')
      embed.description = reply.join('')
    end
    message.react(DELETE_EMOTE)
  end
  nil
end

bot.reaction_add(emoji: DELETE_EMOTE) do |event|
  event.message.delete if event.channel.id == CHANNEL_ID && event.message.mentions.first == event.user && event.message.user == bot.profile
  nil
end

bot.run
