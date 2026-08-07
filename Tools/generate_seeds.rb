#!/usr/bin/env ruby
require 'yaml'
require 'json'
require 'fileutils'

VAULT_DIR = "Sources/Resources/Vault"
SEEDS_DIR = "Sources/Resources/Seeds"

FileUtils.mkdir_p(SEEDS_DIR)

def parse_frontmatter(file_path)
  content = File.read(file_path)
  if content =~ /\A(---\s*\n.*?\n?)^(---\s*$\n?)/m
    YAML.load($1)
  else
    {}
  end
end

# Match a section by any of several possible header names (case-insensitive,
# tolerant of trailing punctuation like "Stop rules" vs "Stop rule, unusual").
def extract_section(content, *names)
  names.each do |name|
    match = content.match(/^##\s+#{Regexp.escape(name)}.*?\n(.*?)(?:\n^## |\z)/mi)
    return match[1].strip if match
  end
  ""
end

# 1. Modules
modules = []
Dir.glob("#{VAULT_DIR}/03 Modules/*.md").each do |file|
  next if file.end_with?("Modules MOC.md")
  name = File.basename(file, ".md")
  content = File.read(file)
  fm = parse_frontmatter(file)

  modules << {
    "id" => name,
    "name" => name,
    "folder" => "03 Modules",
    "trains" => fm["trains"] || [],
    "blocks" => fm["blocks"] || [],
    "frequency" => fm["frequency"] || "",
    "placement" => fm["placement"] || "",
    "dose" => extract_section(content, "Dose", "Protocol", "The session", "Template", "The ladder"),
    "progressionRule" => extract_section(content, "Progression", "Progression order"),
    "stopRules" => extract_section(content, "Stop rules", "Stop rule", "Rules", "Red flags — stop and see a clinician")
  }
end

File.write("#{SEEDS_DIR}/modules.json", JSON.pretty_generate(modules))

# 2. Sessions (from 02 Plan/Session Templates/)
sessions = []
Dir.glob("#{VAULT_DIR}/02 Plan/Session Templates/*.md").each do |file|
  name = File.basename(file, ".md")
  content = File.read(file)
  
  # Extract ordered items (lines starting with - [[Module]])
  items = content.scan(/-\s*\[\[([^\]]+)\]\]/).flatten
  
  sessions << {
    "id" => name,
    "name" => name,
    "items" => items
  }
end
# Add Recovery and Off templates
sessions << { "id" => "Recovery", "name" => "Recovery", "items" => [] }
sessions << { "id" => "Off", "name" => "Off", "items" => [] }

File.write("#{SEEDS_DIR}/sessions.json", JSON.pretty_generate(sessions))

# 3. Plan (hardcoded per §5.1)
plan_weeks = []
blocks = [
  { "id" => "Block 0", "name" => "Baseline Week" },
  { "id" => "Block 1", "name" => "Base" },
  { "id" => "Block 2", "name" => "Max Strength" },
  { "id" => "Block 3", "name" => "Power and RFD" },
  { "id" => "Block 4", "name" => "Peak and Send" }
]

(0..22).each do |w|
  block = case w
          when 0 then "Block 0"
          when 1..7 then "Block 1"
          when 8..13 then "Block 2"
          when 14..18 then "Block 3"
          when 19..22 then "Block 4"
          end
  kind = case w
         when 0, 11, 22 then "test"
         when 7, 13, 18 then "reduced"
         when 19, 20, 21 then "taper"
         else "training"
         end
  plan_weeks << { "week" => w, "blockID" => block, "kind" => kind }
end
plan_data = { "weeks" => plan_weeks, "blocks" => blocks }
File.write("#{SEEDS_DIR}/plan.json", JSON.pretty_generate(plan_data))

# 4. Tests
tests = [
  {"id" => "7s_max_hang", "name" => "7 s two-arm max hang"},
  {"id" => "2rm_pull", "name" => "2RM weighted pull-up"},
  {"id" => "critical_force", "name" => "Critical force"},
  {"id" => "mobility", "name" => "Mobility (box split, dorsiflexion, hip)"},
  {"id" => "shoulder_screen", "name" => "Shoulder screen"},
  {"id" => "skill_markers", "name" => "Skill markers (video, slips, attempts)"},
  {"id" => "bodyweight", "name" => "Bodyweight"}
]
test_data = { "items" => tests, "testWeeks" => [0, 11, 22] }
File.write("#{SEEDS_DIR}/tests.json", JSON.pretty_generate(test_data))

# 5. Benchmarks
benchmarks = {
  "twoArm7sHang" => {
    "V4" => 128, "V5" => 134, "V6" => 140, "V7" => 146,
    "V8" => 152, "V9" => 158, "V10" => 164, "V11" => 170
  },
  "oneArmPull" => {
    "V14" => 106, "V15" => 110, "V16" => 114, "V17" => 118
  },
  "conditions" => {
    "excellent" => -100..0, "veryGood" => 0..5, "good" => 5..10, "marginal" => 10..15, "poor" => 15..100
  },
  "readinessRuleFlags" => [
    "hrv_drop", "sleep_under_7", "rhr_up_5", "motivation_flat", "finger_stiff"
  ]
}
File.write("#{SEEDS_DIR}/benchmarks.json", JSON.pretty_generate(benchmarks))

puts "Seed generation complete."
puts "plan.json: #{plan_data["weeks"].count} weeks, #{plan_data["blocks"].count} blocks, #{plan_data["weeks"].count {|w| w["kind"] == "reduced"}} reduced weeks"
puts "modules.json: #{modules.count} modules"
puts "sessions.json: #{sessions.count} session templates"
puts "tests.json: #{test_data["items"].count} test items, #{test_data["testWeeks"].count} test weeks"
puts "benchmarks.json: 2 finger tables, 1 conditions table, 1 readiness rule"
