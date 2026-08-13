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

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/AdamJ2009/Alces-Sacct-V2.git
