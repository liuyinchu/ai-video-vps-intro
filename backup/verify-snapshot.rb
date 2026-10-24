# encoding: UTF-8
require 'digest'
require 'json'
root = File.expand_path(ARGV.fetch(0))
manifest = ARGV.fetch(1)
entries = File.readlines(manifest, encoding: 'UTF-8', chomp: true).map do |row|
  hash, bytes, mode, path = row.split("\t", 4)
  abort "Invalid path in manifest: #{path}" if path.nil? || path.start_with?('/') || path.split('/').include?('..')
  file = File.join(root, path)
  abort "Missing file: #{path}" unless File.file?(file) && !File.symlink?(file)
  abort "Size mismatch: #{path}" unless File.size(file) == bytes.to_i
  abort "SHA256 mismatch: #{path}" unless Digest::SHA256.file(file).hexdigest == hash
  abort "Mode mismatch: #{path}" unless (File.stat(file).mode & 0777).to_s(8) == mode
  {path: path, bytes: bytes.to_i}
end
actual = Dir.chdir(root) { Dir.glob('**/*', File::FNM_DOTMATCH).select { |p| File.file?(p) && !File.symlink?(p) }.sort }
expected = entries.map { |entry| entry[:path] }.sort
abort "Unexpected or missing files: #{(actual - expected) + (expected - actual)}" unless actual == expected
puts JSON.pretty_generate({
  status: 'passed',
  fileCount: entries.length,
  totalBytes: entries.sum { |entry| entry[:bytes] },
  checks: ['sha256', 'size', 'mode', 'exact_file_set']
})

