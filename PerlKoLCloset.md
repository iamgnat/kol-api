

# Introduction #

This module processes closet.php and provides methods to manipulate the items and meat in your closet.

**Note:** Currently anything dealing with a character's inventory (Inventory, Closest, Mall, etc..) is **VERY** slow due to how the item details are gathered (request to Wiki and KoL). There is some internal caching going on, but the first request for items will be slow. Better ways need to be found to pre-cache the information that eats up so much time and so many requests.

## Methods ##
### new(%args) ###
This is the constructor of the object.

The argument is a hash that can contain the following information:

| **Key** | **Required** | **Description** |
|:--------|:-------------|:----------------|
| session | Yes | The [KoL::Session](PerlKoLSession.md) instance to bind to. |

**Example:**

```
my $clos = KoL::Closet->new('session' => $sess);
```

### meat() ###
Returns the amount of meat currently in the closet.

If there is an error, -1 is returned and _$@_ is set.

**Example:**
```
my $meat = $clos->meat();
if ($meat < 0) {
    print "Unable to get closet meat: $@\n";
}
```

### items() ###
Returns a hash reference all the items currently in the closet. The keys to the hash are the names of the items.

_undef_ is returned and _$@_ is set if there is an error.

**Example:**
```
my $items = $clos->items();
if (!defined($items)) {
    print "Unable to get item list: $@\n";
}
```

### putMeat($meat) ###
Puts _$meat_ into your closet.

Returns 1 on success or 0 on failure. In the event of an error, _$@_ is set.

**Example:**
```
if (!$clos->putMeat(999999)) {
    print "Unable to put meat in closet: $@\n";
}
```

### takeMeat($meat) ###
Attempts to take _$meat_ from your closet.

Returns 1 on success or 0 on failure. In the event of an error, _$@_ is set.

**Example:**
```
if (!$clos->takeMeat(999999)) {
    print "Unable to take meat from closet: $@\n";
}
```

### putItems(@items) ###
Attempts to put the given _@items_ into your closet. The maximum number of items that can be put at one time is 11.

Each element of _@items_ can take one of two forms and your array may contain a mix of both forms.

The first form is simply a KoL::Item::`*` (e.g. KoL::Item::Misc, KoL::Item::Booze, etc..) instance reference. In this case all instances of that item in your inventory will be transfered to the closet.

The second form is a two element array reference where the first element a KoL::Item::`*` instance reference and the second is the number of instances to be transfered.

If there is an error, 0 is returned and _$@_ is set. Otherwise 1 is returned.

**Example:**
```
# Put all your booze in the closet!
my $items = $inv->booze();
# ...
my (@items);
foreach my $name (keys(%{$items})) {
    push (@items, [$items->{$name}, $items->{$name}->count()]);
    if (@items == 11) {
        if (!$clos->putItems(@items)) {
            print "Unable to put items in inventory: $@\n";
        }
        @items = ();
    }
}
if (@items > 0 && @items < 11) {
    if (!$clos->putItems(@items)) {
        print "Unable to put items in inventory: $@\n";
    }
    @items = ();
}
```

### takeItems(@items) ###
Attempts to take the given _@items_ from your closet. The maximum number of items that can be taken at one time is 11.

Each element of _@items_ can take one of two forms and your array may contain a mix of both forms.

The first form is simply a KoL::Item::`*` (e.g. KoL::Item::Misc, KoL::Item::Booze, etc..) instance reference. In this case all instances of that item in your closet will be transfered to the inventory.

The second form is a two element array reference where the first element a KoL::Item::`*` instance reference and the second is the number of instances to be transfered.

If there is an error, 0 is returned and _$@_ is set. Otherwise 1 is returned.

**Example:**
```
# Clean that closet.
my $items = $clos->items();
# ...
my (@items);
foreach my $name (keys(%{$items})) {
    push (@items, [$items->{$name}, $items->{$name}->count()]);
    if (@items == 11) {
        if (!$clos->takeItems(@items)) {
            print "Unable to take items from the inventory: $@\n";
        }
        @items = ();
    }
}
if (@items > 0 && @items < 11) {
    if (!$clos->takeItems(@items)) {
        print "Unable to take items from the inventory: $@\n";
    }
    @items = ();
}
```