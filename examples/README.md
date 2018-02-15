# Examples

This folder contains 4 different examples how AutoCanary24 can be used. You should have set the AWS credentials before you execute them.

## 1) Switch complete stacks at once not keeping the inactive stack

How to run: `rake sample_1`

| Steps     |      |
| :------------- | :------------- |
| Initial state: All the traffic goes to blue stack        |   <img src="../docs/autocanary_100_none.png" height="150" /> |
| Green stack is created                                   |   <img src="../docs/autocanary_100_0.png" height="150" /> |
| Green stack gets all the traffic                         |   <img src="../docs/autocanary_0_100.png" height="150" />  |
| Blue stack will be deleted                               |   <img src="../docs/autocanary_none_100.png" height="150" />  |

## 2) Switch complete stacks at once keeping the inactive stack

How to run: `rake sample_2`

| Steps     |      |
| :------------- | :------------- |
| Initial state: All the traffic goes to blue stack                 |   <img src="../docs/autocanary_100_none.png" height="150" /> |
| Green stack is created                                            |   <img src="../docs/autocanary_100_0.png" height="150" /> |
| Green stack gets all the traffic. Blue stack will not be deleted  |   <img src="../docs/autocanary_0_100.png" height="150" />  |

## 3) Switch incrementally the stacks keeping the inactive stack

How to run: `rake sample_3`

| Steps     |      |
| :------------- | :------------- |
| Initial state: All the traffic goes to blue stack        |   <img src="../docs/autocanary_100_0.png" height="150" /> |
| Green stack gets some traffic                            |   <img src="../docs/autocanary_80_20.png" height="150" /> |
| Green stack gets more traffic                            |   <img src="../docs/autocanary_50_50.png" height="150" /> |
| Green stack gets even more traffic                       |   <img src="../docs/autocanary_20_80.png" height="150" /> |
| Final state: All the traffic goes to green stack         |   <img src="../docs/autocanary_0_100.png" height="150" /> |


## 4) Switch incrementally the stacks and rollback

How to run: `rake sample_4`

| Steps     |      |
| :------------- | :------------- |
| Initial state: All the traffic goes to blue stack        |   <img src="../docs/autocanary_100_none.png" height="150" /> |
| Green stack is created                                   |   <img src="../docs/autocanary_100_0.png" height="150" /> |
| Green stack gets some traffic                            |   <img src="../docs/autocanary_80_20.png" height="150" /> |
| Green stack gets more traffic                            |   <img src="../docs/autocanary_50_50.png" height="150" /> |
| Rollback: All the traffic goes again to blue stack       |   <img src="../docs/autocanary_100_0.png" height="150" /> |

## 5) Switch complete stacks at once and roll back when health check fails

How to run: `rake sample_5`

| Steps     |      |
| :------------- | :------------- |
| Initial state: All the traffic goes to blue stack                 |   <img src="../docs/autocanary_100_none.png" height="150" /> |
| Green stack is created                                            |   <img src="../docs/autocanary_100_0.png" height="150" /> |
| Green stack gets all the traffic. Blue stack will not be deleted  |   <img src="../docs/autocanary_0_100.png" height="150" />  |
| The health check fails                                            |   <img src="../docs/autocanary_0_100.png" height="150" />  |
| Rollback: All the traffic goes again to blue stack                |   <img src="../docs/autocanary_100_0.png" height="150" /> |

## 6) Switch complete stacks at once and clean up when health check succeeds

How to run: `rake sample_6`

| Steps     |      |
| :------------- | :------------- |
| Initial state: All the traffic goes to blue stack                 |   <img src="../docs/autocanary_100_none.png" height="150" /> |
| Green stack is created                                            |   <img src="../docs/autocanary_100_0.png" height="150" /> |
| Green stack gets all the traffic. Blue stack will not be deleted  |   <img src="../docs/autocanary_0_100.png" height="150" />  |
| The health check succeeds                                         |   <img src="../docs/autocanary_0_100.png" height="150" />  |
| Blue stack will be deleted                                        |   <img src="../docs/autocanary_none_100.png" height="150" />  |
