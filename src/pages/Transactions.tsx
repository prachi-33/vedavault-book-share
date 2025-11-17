import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/hooks/useAuth';
import { Header } from '@/components/Header';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { useToast } from '@/hooks/use-toast';
import { format } from 'date-fns';

interface Transaction {
  transaction_id: string;
  book_id: string;
  borrower_id: string;
  lend_date: string;
  return_date: string;
  due_date: string;
  transaction_type: string;
  status: string;
  books: {
    title: string;
    author: string;
    owner_id: string;
  };
  borrower: {
    name: string;
  };
}

const Transactions = () => {
  const { user } = useAuth();
  const { toast } = useToast();
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (user) {
      fetchTransactions();
    }
  }, [user]);

  const fetchTransactions = async () => {
    const { data, error } = await supabase
      .from('transactions')
      .select(`
        *,
        books (title, author, owner_id),
        borrower:profiles!transactions_borrower_id_fkey (name)
      `)
      .order('created_at', { ascending: false });

    if (error) {
      toast({
        variant: 'destructive',
        title: 'Error',
        description: 'Failed to fetch transactions',
      });
    } else {
      setTransactions(data || []);
    }
    setLoading(false);
  };

  const handleApprove = async (transactionId: string) => {
    const { error } = await supabase
      .from('transactions')
      .update({ status: 'approved' })
      .eq('transaction_id', transactionId);

    if (error) {
      toast({
        variant: 'destructive',
        title: 'Error',
        description: 'Failed to approve transaction',
      });
    } else {
      toast({
        title: 'Approved!',
        description: 'Book lending request approved',
      });
      fetchTransactions();
    }
  };

  const handleReject = async (transactionId: string) => {
    const { error } = await supabase
      .from('transactions')
      .update({ status: 'rejected' })
      .eq('transaction_id', transactionId);

    if (error) {
      toast({
        variant: 'destructive',
        title: 'Error',
        description: 'Failed to reject transaction',
      });
    } else {
      toast({
        title: 'Rejected',
        description: 'Book lending request rejected',
      });
      fetchTransactions();
    }
  };

  const handleMarkReturned = async (transactionId: string) => {
    const { error } = await supabase
      .from('transactions')
      .update({ status: 'completed' })
      .eq('transaction_id', transactionId);

    if (error) {
      toast({
        variant: 'destructive',
        title: 'Error',
        description: 'Failed to mark as returned',
      });
    } else {
      toast({
        title: 'Success!',
        description: 'Book marked as returned',
      });
      fetchTransactions();
    }
  };

  if (!user) {
    return (
      <>
        <Header />
        <div className="container mx-auto px-4 py-8">
          <p className="text-center text-muted-foreground">Please sign in to view transactions.</p>
        </div>
      </>
    );
  }

  return (
    <>
      <Header />
      <div className="container mx-auto px-4 py-8">
        <h1 className="text-3xl font-bold mb-6">Transactions</h1>

        {loading ? (
          <p className="text-center text-muted-foreground">Loading...</p>
        ) : transactions.length === 0 ? (
          <p className="text-center text-muted-foreground">No transactions yet.</p>
        ) : (
          <div className="space-y-4">
            {transactions.map((transaction) => {
              const isOwner = transaction.books.owner_id === user.id;
              const isBorrower = transaction.borrower_id === user.id;

              return (
                <Card key={transaction.transaction_id}>
                  <CardHeader>
                    <CardTitle className="flex justify-between items-center">
                      <span>{transaction.books.title}</span>
                      <Badge
                        variant={
                          transaction.status === 'approved'
                            ? 'default'
                            : transaction.status === 'pending'
                            ? 'secondary'
                            : transaction.status === 'completed'
                            ? 'outline'
                            : 'destructive'
                        }
                      >
                        {transaction.status}
                      </Badge>
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <p className="text-sm text-muted-foreground mb-2">
                      by {transaction.books.author}
                    </p>
                    <p className="text-sm mb-2">
                      {isBorrower ? 'You are borrowing' : `Borrower: ${transaction.borrower.name}`}
                    </p>
                    {transaction.lend_date && (
                      <p className="text-sm">
                        Lent: {format(new Date(transaction.lend_date), 'MMM dd, yyyy')}
                      </p>
                    )}
                    {transaction.due_date && (
                      <p className="text-sm">
                        Due: {format(new Date(transaction.due_date), 'MMM dd, yyyy')}
                      </p>
                    )}
                    {transaction.return_date && (
                      <p className="text-sm">
                        Returned: {format(new Date(transaction.return_date), 'MMM dd, yyyy')}
                      </p>
                    )}

                    {isOwner && transaction.status === 'pending' && (
                      <div className="flex gap-2 mt-4">
                        <Button
                          size="sm"
                          onClick={() => handleApprove(transaction.transaction_id)}
                        >
                          Approve
                        </Button>
                        <Button
                          size="sm"
                          variant="destructive"
                          onClick={() => handleReject(transaction.transaction_id)}
                        >
                          Reject
                        </Button>
                      </div>
                    )}

                    {isOwner && transaction.status === 'approved' && (
                      <Button
                        size="sm"
                        className="mt-4"
                        onClick={() => handleMarkReturned(transaction.transaction_id)}
                      >
                        Mark as Returned
                      </Button>
                    )}
                  </CardContent>
                </Card>
              );
            })}
          </div>
        )}
      </div>
    </>
  );
};

export default Transactions;
