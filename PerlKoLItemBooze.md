

# Introduction #

This object represents a Booze item.

This object is a subclass of [KoL::Item::Misc](PerlKoLItemMisc.md). Please see the documentation for more details on the functionality of this object.

## Methods ##
### new(%args) ###
This is the constructor of the object and should only ever be called by [KoL::Item->new()](PerlKoLItem#new(%args).md).

This object does not take any additional hash arguments beyond what [KoL::Item::Misc->new()](PerlKoLItemMisc#new(%args).md) uses.

### drink($count) ###
Attempts to drink _$count_ instances of your booze item. If not specified, _$count_ defaults to 1.

On error it returns _undef_ and sets _$@_. On success it returns a hash reference where the key is what you gained/acquired (e.g. Adventures, Drunkenness, etc..) and the value is number you gained. Note that for sub-stats, it will list each type you gained rather than grouping them together.

**Example:**
```
my $name = "can of Swiller";
my $items = $inv->allItems();
$log->msg("Drinking 1 out of " . $items->{$name}->count() . " of $name");
my $results = $items->{$name}->drink();
if (!$results) {
    $log->error("Unable to drink item: $@");
    $sess->logout();
    exit(1);
}
print Dumper($results);
$log->msg("We now have " . $items->{$name}->count() . " left.");
```