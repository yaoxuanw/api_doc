# coding:utf-8
require 'httparty'
require 'PP'
require 'json'

class String
  def to_bool
    return true   if self == true   || self =~ (/(true|t|yes|y|1)$/i)
    return false  if self == false  || self.empty? || self =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end
end

class ApiDocCrawler
  include HTTParty
  base_uri 'http://localhost:3000/api'

  def initialize(fin, fout, u, p)
    @auth = { username: u, password: p }
    @in_lines = File.readlines(fin).map(&:split)
    .delete_if do |v|
      v.empty? || /\A#.*\z/ =~ v[0]
    end
    .each do |v|
      v[0] = v[0].downcase.to_sym
      v[2] = eval(v[2])
      v[3] = v[3].to_bool
    end
    @out_lines = []
    @fout = fout
  end

  def prepare_in_line_for_display(line)
    method, uri, params, need_auth, comment = line
    # method
    method = method.upcase
    # basic auth
    if params.include?(:basic_auth)
      basic_auth = params.delete(:basic_auth)
    end
    # params
    if method == :get && params.include?(:query)
      new_params = params[:query]
    elsif ( method == :put || method == :post ) && params.include?(:body)
      new_params = params[:body]
    else
      new_params = params
    end

    # modify
    line[0] = method.upcase
    line[2] = JSON.pretty_generate(new_params) unless new_params.nil? || new_params.empty?
    line.insert(2, JSON.pretty_generate(basic_auth)) unless basic_auth.nil? || basic_auth.empty?
    line.rotate(-1)
  end

  def prepare_out_line_for_display(response)
    [JSON.pretty_generate(JSON.parse(response.body)),
     [response.code, response.message].join(' ')]
  end

  def start
    @in_lines.each do |line|
      raise 'need at least 3 fields per line' if line.length < 3
      method, uri, params, need_auth, comment = line
      raise 'params should be hash' unless params.is_a?(Hash)
      params.merge!(basic_auth: @auth) if need_auth
      response = self.class.send(method, uri, params)
      # for output
      new_in_line = prepare_in_line_for_display(line)
      new_out_line = prepare_out_line_for_display(response)
      @out_lines << [new_in_line, new_out_line]
    end
  end

  def show
    File.open(@fout, 'w') do |f|
      curr_index = 0
      @out_lines.each do |in_line, out_line|
        f.puts "\n======= #{curr_index} ========\n"
        in_line.each do |field|
          f.puts "\n#{field}\n"
        end
        f.puts "\n++++++++++++++++++\n"
        out_line.each do |field|
          f.puts "\n#{field}\n"
        end
        f.puts "\n======= #{curr_index} ========\n"
        curr_index += 1
      end
    end
  end

end

raise 'Usage: executable input_file output_file' if ARGV.length < 2
args = ARGV[0..1] + ['dg5KD4K3isxU8J7tmEWY', 'x']
agent = ApiDocCrawler.new(*args)
agent.start
agent.show
