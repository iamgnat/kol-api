

# Introduction #

This module processes charpane.php and provides methods to view it's information.

## Methods ##
### new(%args) ###
This is the constructor of the object.

The argument is a hash that can contain the following information:

| **Key** | **Required** | **Description** |
|:--------|:-------------|:----------------|
| session | Yes | The [KoL::Session](PerlKoLSession.md) instance to bind to. |

**Example:**

```
my $stats = KoL::Stats->new('session' => $sess);
```

### level() ###
Returns the user's numerical level.

**Example:**
`my $level = $stats->level();`

### title() ###
Returns the user's level title (e.g. Alligator Subjugator).

**Example:**
`my $title = $stats->title();`

### meat() ###
Returns the amount of meat the user current has.

**Example:**
`my $meat = $stats->meat();`

### turns() ###
Returns the number of turns the user has remaining.

**Example:**
`my $meat = $stats->meat();`

### drunkenness() ###
Returns the current level of drunkenness.

**Example:**
`my $drunk = $stats->drunkenness();`

### lastAdventure() ###
The area name of the last adventure (e.g. Spooky Forest).

**Note:** Honestly i'm not what this might be useful for...

**Example:**
`my $last = $stats->lastAdventure();`

### effects() ###
Returns a hash reference of the effects on the user.

The key is the effect name and the value is a hash reference with the following items:
| **Key** | **Value** |
| id | The effect id. |
| name | The name of the effect. |
| count | The number of turns remaining. |

**Note:** Effects may end up getting their own object in the future. Dunno yet.

**Example:**
```
my $effects = $stats->effects();
foreach my $name (keys(%{$effects})) {
    print "$name (" . $effects->{$name} . ")\n";
}
```

### muscle() ###
### mysticality() ###
### moxie() ###
Returns the given stat in a 2 element array format where the first element is the buffed value and the second is the base value.

**Example:**
```
my ($buffMus, $baseMus) = $stats->muscle();
my ($buffMys, $baseMys) = $stats->mysticality();
my ($buffMox, $baseMox) = $stats->moxie();
```

### hp() ###
### mp() ###
Returns the current values in a 2 element array format where the first element is the current value and the second is the max value.

**Example:**
```
my ($currHp, $maxHp) = $stats->hp();
my ($currMp, $maxMp) = $stats->Mp();
```