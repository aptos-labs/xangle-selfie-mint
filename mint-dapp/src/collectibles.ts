import { AptosAccount, AptosClient, TokenClient, type Types } from 'aptos';

type UserTransaction = Types.UserTransaction;

export const defaultRequestErrorAttributes = {
  config: {},
  headers: {},
  status: 400,
  statusText: 'Move abort',
};

const ERROR_CODES = Object.freeze({
  URI_GENERAL: 'URI is invalid',
  URI_METADATA_FORMAT: 'Wrong metadata format in URI',
} as const);

export interface RaiseForErrorProps {
  error?: string;
  vmStatus?: string;
}

// TODO: map to ApiError, seems to complicated to be worth it now
class RequestError extends Error {
  constructor(msg: string, public response: any) {
    super(msg);
  }
}

const raiseForError = ({ error, vmStatus }: RaiseForErrorProps) => {
  if (error?.includes(ERROR_CODES.URI_METADATA_FORMAT)) {
    throw new RequestError(error, {
      data: {
        message: error,
      },
      ...defaultRequestErrorAttributes,
      statusText: error,
    });
  } else if (vmStatus?.includes('Move abort')) {
    throw new RequestError(vmStatus, {
      data: {
        message: vmStatus,
      },
      ...defaultRequestErrorAttributes,
    });
  }
};

interface CreateTokenAndCollectionProps {
  collectionName?: string;
  description?: string;
  name?: string;
  royalty_points_per_million?: number;
  supply: number;
  uri?: string;
}

export const createTokenAndCollection = async (
  account: AptosAccount,
  aptosClient: AptosClient,
  {
    collectionName,
    description,
    name,
    royalty_points_per_million = 0,
    supply,
    uri,
  }: CreateTokenAndCollectionProps,
) => {
  if (!account || !(collectionName && description && uri && name)) {
    return undefined;
  }
  const tokenClient = new TokenClient(aptosClient);

  const collectionTxnHash = await tokenClient.createCollection(
    account,
    collectionName,
    description,
    uri,
    1,
  );

  // Move abort errors do not throw so we need to check them manually
  const collectionTxn = await aptosClient.waitForTransactionWithResult(
    collectionTxnHash,
  );
  let vmStatus: string = (collectionTxn as UserTransaction).vm_status;
  raiseForError({ vmStatus });

  const tokenTxnHash = await tokenClient.createToken(
    account,
    collectionName,
    name,
    description,
    supply,
    uri,
    supply,
    account.address(),
    royalty_points_per_million,
    0,
  );
  const tokenTxn: any = await aptosClient.waitForTransactionWithResult(
    tokenTxnHash,
  );
  vmStatus = tokenTxn.vm_status;
  raiseForError({ vmStatus });

  return {
    address: account.address().hex(),
    amount: '1',
    collection: collectionName,
    description,
    name,
    uri,
  };
};

export default createTokenAndCollection;
