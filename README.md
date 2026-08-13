# AlcesSacct

Ruby tool to help assist in metric calculation for SLURM sacct

## Installation

Install the gem and add to the application by cloning this repository
```
git clone https://github.com/AdamJ2009/Alces-Sacct-V2.git
cd Alces-Sacct-V2
bundle exec rake install.
```


## Usage

```
sacct-reporter report [options]
```
### Options

```
  --csv=VALUE, -c VALUE             # Output CSV filename
  --end=VALUE, -E VALUE             # Endtime in ISO format
  --partition=VALUE, -p VALUE       # Filter by partition
  --start=VALUE, -S VALUE           # Starttime in ISO format
  --state=VALUE, -s VALUE           # States as comma seperated list
  --[no-]user, -u                   # Filter by user (defaults to current user)
  --[no-]unknown-user, -U           # Filter strictly for jobs with no user ID/association
  --help, -h                        # Print this help
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/AdamJ2009/Alces-Sacct-V2.git
