require 'discordrb'
require 'yaml'
require 'rubocop'

CHANNEL_ID = 83_281_822_225_530_880
ROLE_IDS = [209_033_538_329_116_682, 111_173_097_888_993_280, 103_548_885_602_942_976].freeze
RUBOCOP_EMOTE = 'rubocop%3A246708457460334592'.freeze
RUBOCOP_EMOTE_ID = 246_708_457_460_334_592
PASS_EMOTE = 'helYea%3A236243426662678528'.freeze
FAIL_EMOTE = 'helNa%3A239120424938504192'.freeze
DELETE_EMOTE = '❌'.freeze

@secrets = YAML.load_file('secret.yml')
@cop_hash = {}
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
      RuboCop::Cop::Style::InitialIndentation,
      RuboCop::Cop::Style::NumericLiterals,
      RuboCop::Cop::Style::TrailingBlankLines,
      RuboCop::Cop::Lint::UselessAssignment
    ]
end

def rubocop_team
  config = RuboCop::ConfigLoader.default_configuration
  RuboCop::Cop::Team.new(my_cops, config)
end

bot.message(in: CHANNEL_ID, contains: /```(?:ruby|rb)\n[\s\S]+```/i) do |event|
  event.message.react(RUBOCOP_EMOTE)
end

bot.reaction_add(emoji: RUBOCOP_EMOTE_ID) do |event|
  if event.message.author == bot.profile
    next unless [
      event.channel.id == CHANNEL_ID,
      event.message.mentions.first == event.user || !(event.user.on(event.channel.server).roles & ROLE_IDS).empty?
    ].all?
  else
    next unless [
      event.channel.id == CHANNEL_ID,
      event.message.content.match?(/```(?:ruby|rb)\n[\s\S]+```/i),
      event.message.author == event.user || !(event.user.on(event.channel.server).roles & ROLE_IDS).empty?,
      !@cop_hash[event.message.id]
    ].all?
    reply = []
    event.message.content.scan(/```(?:ruby|rb)\n([\s\S]+?)```/i).each do |ruby_code|
      message = rubocop_this(rubocop_team, ruby_code[0])
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
      @cop_hash[event.message.id] = message.id
      message.react(RUBOCOP_EMOTE)
      message.react(DELETE_EMOTE)
    end
  end
end

bot.reaction_add(emoji: DELETE_EMOTE) do |event|
  if [
    event.channel.id == CHANNEL_ID,
    event.message.mentions.first == event.user || !(event.user.on(event.channel.server).roles & ROLE_IDS).empty?,
    event.message.user == bot.profile
  ].all?
    event.message.delete
    @cop_hash.delete(@cop_hash.key(event.message.id))
  end
end

bot.run
