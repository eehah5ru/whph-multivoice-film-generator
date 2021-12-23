require 'yaml'
require 'securerandom'
require 'fileutils'
require 'date'
require 'mkmf'
require 'rake'

CONFIG = YAML.load_file('config.yml')

#
# trimmer's tasks logic
#
class Trimmer
  include Rake::DSL

  #
  # generate new trim basename
  #
  def self.build_trim_name(suffix = '')
    cur_time = DateTime.now

    cur_time.strftime('%Y-%m-%d-%H-%M-%S-%L') + suffix
  end

  #
  # trimmer instance
  #
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def src_dir
    CONFIG['trim-n-times']['src-dir'] || 'src'
  end

  def out_dir
    File.join 'out', name
  end

  def cuts_dir
    File.join out_dir, 'cuts'
  end

  def get_task
    raise 'tasks are not defined' if @task.nil?

    @task
  end

  def needed?
    FileList.new("#{cuts_dir}/*").length < CONFIG['trim-n-times']['count']
  end

  def define_tasks
    black_prob = CONFIG['trim-n-times']['black-prob']
    min_len = CONFIG['trim-n-times']['min-len']
    max_len = CONFIG['trim-n-times']['max-len']
    count = CONFIG['trim-n-times']['count']

    directory out_dir
    directory cuts_dir

    @task = task "trimmer:#{name}" => ['trimmer:check:trim_n_times', out_dir, cuts_dir] do
      system "trim-n-times --in=#{src_dir} --out=#{cuts_dir}/ --black=/tmp --black-prob=#{black_prob} --min-len=#{min_len} --max-len=#{max_len} --count=#{count}"
    end
  end
end

class Uniformer
  include Rake::DSL

  attr_reader :name

  def initialize(name)
    @name = name
  end

  def src_dir
    File.join 'out', name, 'cuts'
  end

  def out_dir
    File.join 'out', name, 'cuts_uniformed'
  end

  def get_task
    raise('tasks are not defined') if @task.nil?

    @task
  end

  def uniform_cmd(src, dst)
    # "ffmpeg -vsync 0 -hwaccel cuda -hwaccel_output_format cuda -i #{src} -c:v h264_nvenc -preset hq -profile:v high -tune hq -rc-lookahead 8  -rc cbr_hq -cq 0 -b:v 0 -maxrate 120M -bufsize 240M -c:a pcm_s24le -ar 48000 #{dst}"

    # "ffmpeg -vsync 0 -i #{src} -c:v h264_nvenc -preset lossless -profile:v high -rc-lookahead 8  -rc cbr_hq -cq 0 -b:v 0 -maxrate 120M -bufsize 240M -c:a pcm_s24le -ar 48000 #{dst}"

    # "ffmpeg -vsync 1 -r 30 -i #{src} -video_track_timescale 90000 -c:v h264_nvenc -preset lossless -profile:v high -pix_fmt yuv420p -rc-lookahead 8  -rc cbr_hq -cq 0 -b:v 0 -maxrate 120M -bufsize 240M -max_muxing_queue_size 9999 -r 30 -c:a aac #{dst}"

    # "ffmpeg -vsync drop -r 30 -i #{src} -video_track_timescale 30 -c:v copy -c:a aac -r 30 #{dst}"
    # "ffmpeg -i #{src} -c:v copy -bsf:v h264_mp4toannexb -f mpegts -c:a aac -bsf:a aac_adtstoasc #{dst}"
  end

  def define_tasks
    sources = FileList.new(File.join(src_dir, '*'))

    directory out_dir

    @task = task "uniform-#{name}" => [out_dir]

    sources.each do |s|
      target = s.sub(src_dir, out_dir)

      # force mov container cuz wav audio strem
      # target = File.join(File.dirname(target), (File.basename(target, File.extname(target)) + '.' + CONFIG["container_format"]))

      target = File.join(File.dirname(target), (File.basename(target, File.extname(target)) + '.ts'))

      f = file target => [s] do
        system uniform_cmd(s, target)
      end

      # add prereq to main uniform task
      @task.enhance [f.name]
    end
  end
end

#
# concat videos
#
class Concatenator
  include Rake::DSL

  attr_reader :name

  def initialize(name)
    @name = name
  end

  def src_dir
    File.join('out', name, 'cuts')
  end

  def out_dir
    File.join('out', name)
  end

  def target_file
    # File.join(out_dir, "video-#{name}.#{CONFIG['container_format']}")

    File.join(out_dir, "video-#{name}.mp4")
  end

  def sources_list_file
    File.join(out_dir, "sources.list")
  end

  def root_task
    raise("there are no tasks defined") if @root_task.nil?

    @root_task
  end

  def invoke
    define_tasks

    root_task.invoke
  end

  def concat_cmd
    # "ffmpeg -fflags +igndts -vsync drop  -f concat -safe 0 -i #{sources_list_file}  -c copy -copytb 1 #{target_file}"
    "ffmpeg -vsync 0 -f concat -safe 0 -i #{sources_list_file}  -c copy #{target_file}"
  end

  def define_tasks
    directory out_dir

    # write source file list
    file sources_list_file => [out_dir] do
      File.open(sources_list_file, 'w') do |f|
        FileList.new(File.join(src_dir, '/*')).each do |src_file|
          f.puts "file #{File.expand_path(src_file)}"
        end
      end
    end

    # concat videos
    @root_task = file target_file => [out_dir, sources_list_file] do
      system concat_cmd
    end
  end
end

#
# burn subtitles
#
class SubsBurner
  include Rake::DSL

  attr_reader :name

  def initialize(name)
    @name = name
  end

  def target_file
    File.join('out', name, "video-#{name}-subs-ru-en.#{CONFIG['container_format']}")
  end

  def target_file_ru_only
    File.join('out', name, "video-#{name}-subs-ru.#{CONFIG['container_format']}")
  end

  def source_video_file
    File.join('out', name, "video-#{name}.#{CONFIG['container_format']}")
  end

  def subs_file(lang)
    abort("there is no subs file for lang #{lang}") unless CONFIG["subtitles_#{lang.to_s}"]
    CONFIG["subtitles_#{lang.to_s}"]
  end

  def root_task
    raise('tasks are not defined') if @root_task.nil?

    @root_task
  end

  def invoke
    define_tasks

    root_task.invoke
  end

  def source_video_duration
    cmd = "ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 #{source_video_file}"

    `#{cmd}`.to_f
  end

  # check the video long enough to fit whole subtitles
  def long_enough?
    source_video_duration >= CONFIG['video_duration_secs']
  end

  def burn_subs_cmd(src_file, dst_file, lang)
    "ffmpeg -hwaccel cuda -threads 8 -i #{src_file} -t #{CONFIG['video_duration']} -vf 'ass=#{subs_file(lang)}' -c:v h264_nvenc -preset lossless -profile:v high -rc-lookahead 8  -rc cbr_hq -cq 0 -b:v 0 -maxrate 120M -bufsize 240M -surfaces 16 -c:a copy #{dst_file}"
  end

  def define_tasks
    # burn ru subs
    file target_file_ru_only => [source_video_file, subs_file(:ru)] do
      abort('video is not enough long!') unless long_enough?

      abort('error burning ru subs') unless system(burn_subs_cmd(source_video_file, target_file_ru_only, :ru))

    end

    # burn en subs
    file target_file => [target_file_ru_only, subs_file(:en)] do
      abort('video is not enough long!') unless long_enough?

      abort('error burning en subs') unless system(burn_subs_cmd(target_file_ru_only, target_file, :en))
    end

    @root_task = task "all_subs_#{name}" => [target_file, target_file_ru_only]
  end
end

#
# make small video
#
class MakeSmallVideo
  include Rake::DSL

  attr_reader :name

  def initialize(name)
    @name = name
  end

  def target_file
    File.join('out', name, "video-#{name}-subs-ru-en-small.#{CONFIG['container_format']}")
  end

  def source_file
    File.join('out', name, "video-#{name}-subs-ru-en.#{CONFIG['container_format']}")
  end

  def root_task
    raise('tasks are not defined') if @root_task.nil?

    @root_task
  end

  def invoke
    define_tasks

    root_task.invoke
  end

  def make_small_cmd
    "ffmpeg -vsync 0 -hwaccel cuda -threads 8 -i #{source_file} -c:v h264_nvenc -b:v 2M -surfaces 8 -c:a aac #{target_file}"
  end

  def define_tasks
    @root_task = file target_file => [source_file] do
      abort('error in making small video') unless system make_small_cmd
    end
  end
end

desc 'generate sources'
namespace :sources do
  desc 'create src directory'
  directory 'src'

  def get_sources
    sources = FileList.new
    CONFIG['sources'].each do |src_dir|
      CONFIG['video_suffixes'].each do |suffix|
        sources.add File.join(src_dir, "**/*.#{suffix}")
      end
    end

    exclusions = FileList.new

    CONFIG['sources'].each do |s|
      CONFIG['excluded_subdirs'].each do |e|
        exclusions.add File.join(s, "**/#{e}/**/*")
      end
    end

    sources -= exclusions

    sources
  end

  def good_file? a_file
      # unless File.exists?(f) and File.symlink?(f)
      #   $stderr.puts "broken file - unexists: #{f}"
      #   next
      # end

    return false unless system("mediainfo #{a_file} > /dev/null")

    return false if File.size(a_file) == 0

    true
  end

  desc 'clean src folder'
  task :clean_symlinks => ['src'] do
    FileList.new('src/*') do |f|
      FileUtils.rm_f f
    end
  end

  desc 'create symlinks for all matched source video-files'
  task symlink: ['src', 'sources:clean_symlinks'] do
    get_sources.each do |s|
      next unless good_file? s

      uid = SecureRandom.uuid
      ext = File.extname(s)
      base = File.basename(s, ext).gsub(/\s/, '_').gsub(/[^\w]/, '_')

      target_filename = "#{base}-#{uid}#{ext}"

      target = File.join('src', target_filename)

      FileUtils.symlink(s, target, force: true)
    end
  end

  desc 'check symlinked sources'
  task :check_sources => ['sources:symlink'] do
    FileList.new('src/*').each do |f|
      $stderr.puts "broken file: #{f}" unless good_file? f
    end
  end

  #
  # recode all sources
  #
  directory 'src_recoded'

  desc 'recode all sources'
  task recode: ['src_recoded'] do

    recode_all = task "recode_all"

    FileList.new('src/*').each do |s|
      target = s.sub(/^src/, 'src_recoded')
      target = File.join(File.dirname(target), File.basename(target, File.extname(target)) + "." + CONFIG['container_format'])

      file target => [s] do
        system "ffmpeg -hwaccel cuda -i #{s} -filter:v 'scale=w=1920:h=1080:force_original_aspect_ratio=1,pad=1920:1080:(ow-iw)/2:(oh-ih)/2' -c:v h264_nvenc -cq 0  -b:v 0 -maxrate 120M -profile:v high -surfaces 16 -r 30 -c:a pcm_s24le -ar 48000 #{target}"
      end

      recode_all.enhance [target]
    end

    recode_all.invoke
  end

  desc 'clean src_recoded folder'
  task :clean_src_recoded => ['src_recoded'] do
    FileList.new('src_recoded/*').each do |f|
      FileUtils.rm_f(f)
    end
  end

  desc 'print all matched sources'
  task print: ['src'] do
    get_sources.each do |s_file|
      p s_file
    end
  end
end

desc 'trim videos'
namespace :trimmer do
  def define_trimmer_tasks(trim_name)
  end

  namespace :check do
    desc 'check trim-n-times in PATH'
    task :trim_n_times do
      abort('trim-n-times is not in your PATH') unless find_executable('trim-n-times')

      %w[black-prob min-len max-len count].each do |f|
        abort("there is no trim-n-times->#{f} in config") unless CONFIG['trim-n-times'][f]
      end
    end
  end


  namespace :once do
    #
    # trim name for new video
    #
    new_trim_name = Trimmer.build_trim_name

    #
    # generate random video once
    #
    desc 'generate new random version of movie'
    task :trim, [:trim_name] => %W[src out] do |t, args|
      args.with_defaults(trim_name: new_trim_name)
      trimmer = Trimmer.new args.trim_name

      trimmer.define_tasks

      trimmer.get_task.invoke if trimmer.needed?
    end

    #
    # uniform cuts
    #
    # FIXME: not useful anymore since videos are recoded already
    desc "uniform video cuts"
    task :uniform, [:trim_name] => %w[out trimmer:once:trim] do |t, args|
      args.with_defaults(trim_name: new_trim_name)

      uniformer = Uniformer.new args.trim_name

      uniformer.define_tasks
      uniformer.get_task.invoke
    end

    #
    # concat videos in one
    #
    desc 'concat cuts in one video'
    task :concat, [:trim_name] => %w[trimmer:once:trim] do |t, args|
      args.with_defaults(trim_name: new_trim_name)

      concatenator = Concatenator.new args.trim_name

      concatenator.invoke
    end

    #
    # burn subtitles in video
    #
    desc 'burn subtitles'
    task :burn_subtitles, [:trim_name] => %[trimmer:once:concat] do |t, args|
      args.with_defaults(trim_name: new_trim_name)

      SubsBurner.new(args.trim_name).invoke
    end

    #
    # make small video
    #
    desc 'make small video'
    task :make_small_video, [:trim_name] => %[trimmer:once:burn_subtitles] do |t, args|
      args.with_defaults(trim_name: new_trim_name)

      MakeSmallVideo.new(args.trim_name).invoke
    end

    #
    # do all stuff
    #
    desc 'make a new video'
    task :new => %[trimmer:once:make_small_video]
  end

end

desc 'create output directory'
directory 'out'
