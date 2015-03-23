**WARNING:**

This module is currently under active development. This means that:

  1. The API is not complete and functionality is being added and changed as it is developed.
  1. The documentation is likely not up to date with the code.

Using any functionality of this module at this time is just silly and at your own risk.

You've been warned!



# Introduction #

This object serves as both the object representation for items with no specific type and as the basis for all the objects that sub-class it to represent the different specific types.

## TODO ##

Need to add use (drink, eat, etc..) functionality.

## Methods ##
### new(%args) ###
This is the constructor of the object.

It processes the results of an item description and pulls out the information that is common to all|most items.

| **Key** | **Required** | **Description** |
|:--------|:-------------|:----------------|
| content | Yes | This is the LWP response content of the item description to be processed. |

### getInfo($key) ###
This method is not meant for external use. It is only meant to be called by internal methods to the object or a sub-class.

In basic terms, this method returns the value of the supplied _$key_. Specifically, however, it is only intended to be used for information that was not gather from the item description page (e.g. _count_). Before returning the value it asks the _controller_ to run it's _update()_ method to make sure the most up to date information is being returned.

**Example:**
```
return($self->_getInfo('count'));
```


### type() ###
Returns the type of item by returning the last portion of the object name.

**Example:**
```
print "Item is a " . $item->type() . "\n";
```

### id() ###
Returns the item id.

### name() ###
Returns the name of the item.

### description() ###
Returns the description of the item.

**Note:** This will likely contain HTML formatting.

### descid() ###
Returns the description id.

### tradable() ###
Returns 1|0 if the item can be traded.

### discardable() ###
Returns 1|0 if the item can be discarded.

### meat() ###
Returns the auto sell price.

### quest() ###
Returns 1|0 if the item is a quest item.

### count() ###
Returns the number of instances of the item.

A result of 0 indicates that there are no more instances of the item available in association with the controller (e.g. inventory, closet, display case, clan stash, mall store).

### muscleRequired() ###
Returns the muscle required to use the item or 0.

### mysticalityRequired() ###
Returns the mysticality required to use the item or 0.

### moxieRequired() ###
Returns the moxie required to use the item or 0.

### levelRequired() ###
Returns the level required to use the item or 0.

### setCount($val) ###
This allows you to set the current instance count. This is only intended to be used by the _controller's_ _update()_ method.

### sell($count) ###
Attempts to sell _$count_ of the item. If _$count_ is not given, it defaults to 1.

This may only be called from items in your [KoL::Inventory](PerlKoLInventory.md).

The result on success is the amount of meat the items sold for. If there is an error, 0 is returned and _$@_ is set.

**Example:**
```
my $name = "white satin pants";
my $items = $inv->allItems();
my $count = int($items->{$name}->count() / 2) || 1;
$log->msg("Selling $count out of " . $items->{$name}->count() . " of $name");
my $meat = $items->{$name}->sell($count);
if (!$meat) {
    $log->error("Unable to sell item: $@");
    $sess->logout();
    exit(1);
}
$log->msg("Sold $count for $meat meat.");
$log->msg("We now have " . $items->{$name}->count() . " left.");
```

### discard() ###
Attempts to discard one of the item.

This may only be called from items in your [KoL::Inventory](PerlKoLInventory.md).

Returns 1 on success and 0 if there is an error and _$@_ is set.

**Example:**
```
my $name = "white satin pants";
my $items = $inv->allItems();
$log->msg("Discarding 1 out of " . $items->{$name}->count() . " of $name");
if (!$items->{$name}->discard()) {
    $log->error("Unable to discard item: $@");
    $sess->logout();
    exit(1);
}
$log->msg("We now have " . $items->{$name}->count() . " left.");
```